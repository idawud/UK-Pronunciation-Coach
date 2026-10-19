// Test doubles and a harness for the Read screen and ScoringController (U2-read).
import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/ui/read/scoring_controller.dart';

/// [FakePhonemeRecognizer] with switchable light availability, a load log, an
/// optional gate that holds `recognise` until released, and an optional failure.
class TestRecognizer extends FakePhonemeRecognizer {
  TestRecognizer({
    super.recommended,
    super.fullAvailable,
    this.lightAvailable = true,
  });

  bool lightAvailable;
  final List<ModelTier> loads = [];
  Completer<void>? gate;
  Object? recogniseError;
  ModelDownloadProgress? statusOverride;
  final _extra = StreamController<ModelDownloadProgress>.broadcast();

  /// Emits a download state (also returned by [downloadStatus]).
  void emitDownload(ModelDownloadProgress p) {
    statusOverride = p;
    if (p.state == DownloadState.completed) fullAvailable = true;
    _extra.add(p);
  }

  @override
  ModelDownloadProgress get downloadStatus =>
      statusOverride ?? super.downloadStatus;

  @override
  Stream<ModelDownloadProgress> get downloadProgress => _extra.stream;

  @override
  Future<bool> isTierAvailable(ModelTier tier) async =>
      tier == ModelTier.light ? lightAvailable : fullAvailable;

  @override
  Future<void> load(ModelTier tier) async {
    if (!await isTierAvailable(tier)) throw ModelNotAvailableException(tier);
    loads.add(tier);
    await super.load(tier);
  }

  @override
  Future<PhonemePosteriors> recognise(AudioClip clip) async {
    final g = gate;
    if (g != null) await g.future;
    if (recogniseError case final e?) throw e;
    return super.recognise(clip);
  }

  @override
  Future<void> dispose() async {
    await _extra.close();
    await super.dispose();
  }
}

/// [FakePracticeEngine] that records calls.
class SpyPracticeEngine extends FakePracticeEngine {
  SpyPracticeEngine({required super.content, required super.progress});

  final List<Duration> practiceLogged = [];
  final List<AttemptResult> recorded = [];

  @override
  Future<void> logPracticeTime(Duration duration) {
    practiceLogged.add(duration);
    return super.logPracticeTime(duration);
  }

  @override
  Future<LevelChange?> recordAttempt(AttemptResult result) {
    recorded.add(result);
    return super.recordAttempt(result);
  }
}

/// Everything a Read screen test needs, with overrides for a ProviderScope.
class ReadHarness {
  ReadHarness({
    FakeAudioRecorder? recorder,
    TestRecognizer? recognizer,
    UserProfile profile = const UserProfile(),
  }) : recorder =
           recorder ??
           FakeAudioRecorder(levels: const [], emitSilenceAfterLevels: false),
       recognizer = recognizer ?? TestRecognizer() {
    unawaited(progress.saveProfile(profile));
  }

  final FakeAudioRecorder recorder;
  final TestRecognizer recognizer;
  final content = FakeContentRepository();
  late final progress = FakeProgressRepository(clock: () => now);
  late final engine = SpyPracticeEngine(content: content, progress: progress);
  final scorer = FakePronunciationScorer();
  final List<String> deleted = [];
  DateTime now = DateTime(2026, 10, 19, 9);

  List<Override> get overrides => [
    clockProvider.overrideWithValue(() => now),
    audioRecorderProvider.overrideWithValue(recorder),
    phonemeRecognizerProvider.overrideWithValue(recognizer),
    pronunciationScorerProvider.overrideWithValue(scorer),
    contentRepositoryProvider.overrideWithValue(content),
    progressRepositoryProvider.overrideWithValue(progress),
    practiceEngineProvider.overrideWithValue(engine),
    recordingDeleterProvider.overrideWithValue((path) async {
      deleted.add(path);
    }),
  ];
}
