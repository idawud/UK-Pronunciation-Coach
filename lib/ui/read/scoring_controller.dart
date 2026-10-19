import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/contracts/contracts.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import 'read_state.dart';

/// Deletes a recording file that will not be saved. Must not throw.
typedef RecordingDeleter = Future<void> Function(String path);

/// How unsaved recordings are deleted. Tests override it to record the calls.
final recordingDeleterProvider = Provider<RecordingDeleter>(
  (ref) => deleteRecordingFile,
);

/// Deletes the file at [path] if it exists, ignoring every error.
Future<void> deleteRecordingFile(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } on Object {
    // Best effort: an unsaved clip that cannot be deleted is not worth an error.
  }
}

/// The Read screen's controller, one per [ReadArgs] (the route's argument object).
final scoringControllerProvider = NotifierProvider.autoDispose
    .family<ScoringController, ReadState, ReadArgs>(ScoringController.new);

/// Rough real-time factor of recognition, used only to estimate progress. A2 measured
/// 0.35-0.75 for the full tier on a desktop CPU.
const double recognitionRealTimeFactor = 0.5;

/// Recording stops by itself after this long (a level-6 passage takes ~90 s).
const Duration maxRecordingDuration = Duration(minutes: 3);

/// Number of level values kept for the waveform.
const int waveformLength = 64;

/// Smallest and largest passage text size multipliers (1.0 = 20 sp).
const double minTextScale = 0.8, maxTextScale = 1.6;

/// Step of the text size buttons.
const double textScaleStep = 0.1;

const Duration _tick = Duration(milliseconds: 100);

/// Runs the Read screen: loads the passage, records, then scores
/// (`AudioRecorder.stop` -> `speechSegments` -> `PhonemeRecognizer.recognise` ->
/// `PronunciationScorer.score`) and saves (passage mode) or hands back the result.
///
/// Also owns two jobs nobody else does:
/// - **Model tier.** Before recognising it makes sure a tier is loaded: the user's
///   `UserProfile.tierOverride` if set, else `recommendedTier()`; when that tier is
///   not on the phone it falls back to the other one (light), and when neither is, it
///   waits for a running full-model download. It warms the model up when the screen
///   opens.
/// - **Practice time.** After every completed recording (not placement) it calls
///   `PracticeEngine.logPracticeTime` with the recording's duration.
class ScoringController extends Notifier<ReadState> {
  /// Creates the controller for [args].
  ScoringController(this.args);

  /// What to read and how.
  final ReadArgs args;

  late AudioRecorder _recorder;
  late PhonemeRecognizer _recognizer;
  late PronunciationScorer _scorer;
  late PracticeEngine _engine;
  late ProgressRepository _progress;
  late ContentRepository _content;
  late Clock _clock;
  late RecordingDeleter _delete;

  StreamSubscription<double>? _levelSub;
  StreamSubscription<void>? _silenceSub;
  StreamSubscription<ModelDownloadProgress>? _downloadSub;
  Timer? _recordTicker;
  Timer? _estimateTicker;
  Completer<void>? _downloadWait;
  DateTime? _recordStart;
  final List<double> _levels = [];
  Future<void>? _warmUp;
  ModelTier? _wantedTier;
  String? _unsavedClip;
  bool _starting = false;
  bool _stopping = false;

  /// Bumped whenever a recording or scoring run is cancelled; stale runs stop.
  int _run = 0;

  @override
  ReadState build() {
    _recorder = ref.read(audioRecorderProvider);
    _recognizer = ref.read(phonemeRecognizerProvider);
    _scorer = ref.read(pronunciationScorerProvider);
    _engine = ref.read(practiceEngineProvider);
    _progress = ref.read(progressRepositoryProvider);
    _content = ref.read(contentRepositoryProvider);
    _clock = ref.read(clockProvider);
    _delete = ref.read(recordingDeleterProvider);
    ref.onDispose(_dispose);
    unawaited(_load());
    return const ReadState(phase: ReadLoading());
  }

  /// The model tier this device wants (override or recommendation), once known.
  ModelTier? get wantedTier => _wantedTier;

  // ---------------------------------------------------------------------------
  // Loading

  Future<void> _load() async {
    try {
      final passage = await _content.byId(args.passageId);
      final content = await _contentFor(passage);
      final profile = await _progress.profile();
      if (!ref.mounted) return;
      state = state.copyWith(
        content: content,
        textScale: profile.textScale.clamp(minTextScale, maxTextScale),
        phase: const ReadIdle(),
      );
    } on PassageNotFoundException {
      _set(const ReadLoadFailed("We couldn't find this passage."));
      return;
    } on RangeError {
      _set(const ReadLoadFailed("We couldn't find this word in the passage."));
      return;
    } on Object {
      _set(const ReadLoadFailed('Something went wrong loading the passage.'));
      return;
    }
    _downloadSub = _recognizer.downloadProgress.listen(
      (_) => _refreshDownloadNotice(),
      onError: (Object _) {},
    );
    _warmUp = _prepareModel(wait: false).then<void>((_) {}, onError: (_) {});
  }

  Future<ReadContent> _contentFor(Passage passage) async {
    int? number;
    int? count;
    if (args.mode == ReadMode.passage) {
      try {
        final level = await _content.byLevel(passage.level);
        final i = level.indexWhere((p) => p.id == passage.id);
        if (i >= 0) {
          number = i + 1;
          count = level.length;
        }
      } on Object {
        // The number is decoration; show the passage without it.
      }
    }
    switch (args.mode) {
      case ReadMode.passage || ReadMode.placement:
        return ReadContent(
          mode: args.mode,
          passage: passage,
          target: passage,
          passageNumber: number,
          passageCount: count,
        );
      case ReadMode.sentence:
        final range = passage.sentenceRange(args.wordIndex!);
        return ReadContent(
          mode: args.mode,
          passage: passage,
          target: passage.slice(range.start, range.end),
          firstWordIndex: range.start,
        );
      case ReadMode.word:
        final i = args.wordIndex!;
        RangeError.checkValidIndex(i, passage.words, 'wordIndex');
        return ReadContent(
          mode: args.mode,
          passage: passage,
          target: passage.slice(i, i + 1),
          firstWordIndex: i,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Model tier

  /// Makes sure a model tier is loaded and returns it.
  ///
  /// Wanted tier: `UserProfile.tierOverride`, else `recommendedTier()`. If it is not
  /// on the phone, uses the other tier (in practice: light while full is not
  /// downloaded). With [wait], when no tier is on the phone but the full model is
  /// downloading, waits for the download (showing its progress) before loading it.
  /// Throws [ModelNotAvailableException] when no tier can be loaded.
  Future<ModelTier> _prepareModel({required bool wait, int? run}) async {
    final profile = await _progress.profile();
    final wanted = profile.tierOverride ?? await _recognizer.recommendedTier();
    _wantedTier = wanted;
    _refreshDownloadNotice();
    ModelTier? tier;
    if (await _recognizer.isTierAvailable(wanted)) {
      tier = wanted;
    } else {
      final other = wanted == ModelTier.full ? ModelTier.light : ModelTier.full;
      if (await _recognizer.isTierAvailable(other)) tier = other;
    }
    if (tier == null) {
      if (!wait || !_recognizer.downloadStatus.isActive) {
        throw ModelNotAvailableException(wanted);
      }
      await _waitForDownload(run!);
      if (_recognizer.downloadStatus.state != DownloadState.completed) {
        throw const ModelNotAvailableException(ModelTier.full);
      }
      tier = ModelTier.full;
    }
    if (_recognizer.loadedTier != tier) await _recognizer.load(tier);
    return tier;
  }

  Future<void> _waitForDownload(int run) async {
    final done = _downloadWait = Completer<void>();
    void show(ModelDownloadProgress p) {
      _setScoring(run, ScoringStage.waitingForDownload, p.fraction);
      if (!p.isActive && !done.isCompleted) done.complete();
    }

    final sub = _recognizer.downloadProgress.listen(show, onError: (_) {});
    show(_recognizer.downloadStatus);
    try {
      await done.future;
    } finally {
      await sub.cancel();
      _downloadWait = null;
    }
  }

  void _refreshDownloadNotice() {
    if (!ref.mounted) return;
    final status = _recognizer.downloadStatus;
    if (_wantedTier == ModelTier.full && status.isActive) {
      state = state.copyWith(downloadNotice: status);
    } else if (state.downloadNotice != null) {
      state = state.copyWith(clearDownloadNotice: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Recording

  /// Starts recording, asking for the microphone permission first if needed.
  /// Does nothing while loading, recording or scoring.
  Future<void> startRecording() async {
    final phase = state.phase;
    if (_starting ||
        state.content == null ||
        phase is ReadLoading ||
        phase is ReadRecording ||
        phase is ReadScoring ||
        phase is ReadDone) {
      return;
    }
    _starting = true;
    try {
      var permission = await _recorder.checkPermission();
      if (permission == MicPermission.denied) {
        permission = await _recorder.requestPermission();
      }
      if (!ref.mounted) return;
      if (permission != MicPermission.granted) {
        _setPermissionDenied(permission);
        return;
      }
      _levels.clear();
      _levelSub = _recorder.level.listen(_onLevel);
      _silenceSub = _recorder.silenceDetected.listen(
        (_) => unawaited(stopRecording()),
      );
      try {
        await _recorder.start();
      } on MicPermissionException catch (e) {
        await _stopStreams();
        _setPermissionDenied(e.state);
        return;
      } on Object {
        await _stopStreams();
        _set(
          const ReadFailed(
            "We couldn't start the microphone. Close other apps that use it and "
            'try again.',
          ),
        );
        return;
      }
      if (!ref.mounted) {
        await _recorder.cancel();
        return;
      }
      _recordStart = _clock();
      _set(const ReadRecording(elapsed: Duration.zero, levels: []));
      _recordTicker = Timer.periodic(_tick, (_) => _onRecordTick());
    } finally {
      _starting = false;
    }
  }

  void _setPermissionDenied(MicPermission permission) => _set(
    ReadPermissionDenied(
      permanently: permission == MicPermission.permanentlyDenied,
    ),
  );

  Duration get _elapsed {
    final start = _recordStart;
    if (start == null) return Duration.zero;
    final d = _clock().difference(start);
    return d.isNegative ? Duration.zero : d;
  }

  void _onLevel(double level) {
    _levels.add(level.clamp(0.0, 1.0));
    if (_levels.length > waveformLength) {
      _levels.removeRange(0, _levels.length - waveformLength);
    }
    _showRecording();
  }

  void _onRecordTick() {
    if (_elapsed >= maxRecordingDuration) {
      unawaited(stopRecording());
    } else {
      _showRecording();
    }
  }

  void _showRecording() {
    if (!ref.mounted || state.phase is! ReadRecording) return;
    _set(ReadRecording(elapsed: _elapsed, levels: List.unmodifiable(_levels)));
  }

  Future<void> _stopStreams() async {
    _recordTicker?.cancel();
    _recordTicker = null;
    await _levelSub?.cancel();
    await _silenceSub?.cancel();
    _levelSub = null;
    _silenceSub = null;
  }

  /// Stops recording (tap, 2 s of silence, or the time limit), logs the practice
  /// time, checks the audio and scores it.
  Future<void> stopRecording() async {
    if (_stopping || state.phase is! ReadRecording) return;
    _stopping = true;
    final run = _run;
    final AudioClip clip;
    try {
      await _stopStreams();
      clip = await _recorder.stop();
    } on Object {
      _stopping = false;
      _set(const ReadFailed('Recording failed. Please try again.'));
      return;
    }
    _stopping = false;
    _unsavedClip = clip.path;
    if (!ref.mounted || run != _run) {
      await _discardClip();
      return;
    }
    // Show "Scoring..." straight away; logging time and VAD come next.
    _setScoring(run, ScoringStage.checkingAudio, 0.02);
    if (args.mode != ReadMode.placement) {
      try {
        await _engine.logPracticeTime(clip.duration);
      } on Object {
        // Practice time is a nice-to-have; never block scoring on it.
      }
    }
    if (clip.quality != AudioQuality.ok) {
      await _discardClip();
      _set(
        ReadRetryNeeded(
          clip.quality == AudioQuality.tooQuiet
              ? RetryReason.tooQuiet
              : RetryReason.tooNoisy,
        ),
      );
      return;
    }
    await _score(clip, run);
  }

  /// Stops recording without scoring and deletes the audio.
  Future<void> discardRecording() async {
    if (state.phase is! ReadRecording) return;
    _run++;
    await _stopStreams();
    await _recorder.cancel();
    _set(const ReadIdle());
  }

  // ---------------------------------------------------------------------------
  // Scoring

  bool _stale(int run) => !ref.mounted || run != _run;

  void _setScoring(int run, ScoringStage stage, double progress) {
    if (_stale(run)) return;
    _set(ReadScoring(stage: stage, progress: progress.clamp(0.0, 0.99)));
  }

  Future<void> _score(AudioClip clip, int run) async {
    try {
      _setScoring(run, ScoringStage.checkingAudio, 0.05);
      final speech = await _recorder.speechSegments(clip);
      if (_stale(run)) return;
      if (speech.isEmpty) {
        await _discardClip();
        _set(const ReadRetryNeeded(RetryReason.noSpeech));
        return;
      }
      _setScoring(run, ScoringStage.preparingModel, 0.1);
      await _warmUp;
      if (_stale(run)) return;
      await _prepareModel(wait: true, run: run);
      if (_stale(run)) return;
      _setScoring(run, ScoringStage.recognising, 0.15);
      _startEstimate(clip.duration, run);
      final PhonemePosteriors posteriors;
      try {
        posteriors = await _recognizer.recognise(clip);
      } finally {
        _estimateTicker?.cancel();
        _estimateTicker = null;
      }
      if (_stale(run)) return;
      _setScoring(run, ScoringStage.scoring, 0.92);
      final result = _scoreFor(clip, posteriors, speech);
      LevelChange? levelChange;
      if (args.mode == ReadMode.passage) {
        _setScoring(run, ScoringStage.saving, 0.96);
        // The repository now owns the file (keeps or deletes it per settings).
        _unsavedClip = null;
        levelChange = await _engine.recordAttempt(result);
      } else {
        await _discardClip();
      }
      if (!ref.mounted) return;
      _set(ReadDone(result: result, levelChange: levelChange));
    } on ModelNotAvailableException {
      if (_stale(run)) return;
      await _discardClip();
      _set(
        const ReadFailed(
          "The speech model isn't on this phone yet. Download it in Settings, "
          'then try again.',
        ),
      );
    } on Object {
      if (_stale(run)) return;
      await _discardClip();
      _set(const ReadFailed('Something went wrong while scoring. Try again.'));
    }
  }

  /// Moves the progress bar from 15% towards 90% over the expected recognition time.
  void _startEstimate(Duration audio, int run) {
    final expectedMs = math.max(
      1000,
      audio.inMilliseconds * recognitionRealTimeFactor,
    );
    var ticks = 0;
    _estimateTicker?.cancel();
    _estimateTicker = Timer.periodic(_tick, (_) {
      ticks++;
      final t = ticks * _tick.inMilliseconds / expectedMs;
      // Linear to the estimate, then creeping towards 90%.
      final f = t <= 1 ? 0.15 + 0.65 * t : 0.9 - 0.1 * math.exp(1 - t);
      _setScoring(run, ScoringStage.recognising, f);
    });
  }

  AttemptResult _scoreFor(
    AudioClip clip,
    PhonemePosteriors posteriors,
    List<Segment> speech,
  ) {
    final content = state.content!;
    final at = _clock();
    switch (content.mode) {
      case ReadMode.passage:
        return _scorer.score(
          content.passage,
          posteriors,
          speech,
          at: at,
          audioPath: clip.path,
        );
      case ReadMode.placement:
        return _scorer.score(content.passage, posteriors, speech, at: at);
      case ReadMode.sentence:
        final r = _scorer.score(content.target, posteriors, speech, at: at);
        return r.copyWith(
          passageId: content.passage.id,
          words: [
            for (final w in r.words)
              w.copyWith(index: w.index + content.firstWordIndex),
          ],
        );
      case ReadMode.word:
        final word = content.passage.words[content.firstWordIndex];
        final w = _scorer.scoreWord(word, posteriors);
        return AttemptResult(
          id: 'word-${at.microsecondsSinceEpoch}',
          passageId: content.passage.id,
          at: at,
          overall: w.score,
          accuracy: w.score,
          fluency: w.score,
          words: [w],
          tier: posteriors.tier,
        );
    }
  }

  /// Stops scoring and returns to the ready state. Recognition cannot be interrupted,
  /// so a running model call finishes in the background and its result is dropped.
  /// No-op while saving (the attempt is being written).
  Future<void> cancelScoring() async {
    final phase = state.phase;
    if (phase is! ReadScoring || phase.stage == ScoringStage.saving) return;
    _run++;
    _estimateTicker?.cancel();
    _estimateTicker = null;
    _completeDownloadWait();
    await _discardClip();
    _set(const ReadIdle());
  }

  void _completeDownloadWait() {
    final wait = _downloadWait;
    if (wait != null && !wait.isCompleted) wait.complete();
  }

  Future<void> _discardClip() async {
    final path = _unsavedClip;
    _unsavedClip = null;
    if (path != null) await _delete(path);
  }

  // ---------------------------------------------------------------------------
  // Permission, retry, text size

  /// Shows the system permission prompt (when the OS still allows it).
  Future<void> requestPermission() async {
    final p = await _recorder.requestPermission();
    if (!ref.mounted) return;
    if (p == MicPermission.granted) {
      _set(const ReadIdle());
    } else {
      _setPermissionDenied(p);
    }
  }

  /// Opens the system settings page for the app.
  Future<bool> openPermissionSettings() => _recorder.openPermissionSettings();

  /// Re-checks the permission (e.g. when the app resumes from the settings page).
  Future<void> recheckPermission() async {
    if (state.phase is! ReadPermissionDenied) return;
    final p = await _recorder.checkPermission();
    if (!ref.mounted || state.phase is! ReadPermissionDenied) return;
    if (p == MicPermission.granted) {
      _set(const ReadIdle());
    } else {
      _setPermissionDenied(p);
    }
  }

  /// Back to the ready state after a retry message or an error.
  void reset() {
    final phase = state.phase;
    if (phase is ReadRetryNeeded ||
        phase is ReadFailed ||
        phase is ReadPermissionDenied) {
      _set(const ReadIdle());
    }
  }

  /// Changes the passage text size by [delta] and saves it to the profile.
  Future<void> changeTextScale(double delta) async {
    final next = ((state.textScale + delta) * 10).round() / 10;
    final scale = next.clamp(minTextScale, maxTextScale);
    if (scale == state.textScale) return;
    state = state.copyWith(textScale: scale);
    try {
      final profile = await _progress.profile();
      await _progress.saveProfile(profile.copyWith(textScale: scale));
    } on Object {
      // The size still applies on this screen; it is just not remembered.
    }
  }

  // ---------------------------------------------------------------------------

  void _set(ReadPhase phase) {
    if (!ref.mounted) return;
    state = state.copyWith(phase: phase);
  }

  void _dispose() {
    _run++;
    _recordTicker?.cancel();
    _estimateTicker?.cancel();
    _completeDownloadWait();
    unawaited(_levelSub?.cancel());
    unawaited(_silenceSub?.cancel());
    unawaited(_downloadSub?.cancel());
    if (_recorder.isRecording) unawaited(_recorder.cancel());
    unawaited(_discardClip());
  }
}
