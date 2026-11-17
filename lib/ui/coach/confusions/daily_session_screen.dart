import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/contracts.dart';
import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../data/coach/coach_store.dart';
import '../../shell/state_views.dart';
import '../../theme/theme.dart';
import 'confusions_providers.dart';
import 'daily_session.dart';
import 'minimal_pair_check.dart';

/// Recordings shorter than this are treated as a tap, not a word.
const Duration _minSayClip = Duration(milliseconds: 300);

/// Today's session: listen to the pairs, then say each word and hear the estimate.
///
/// Speech comes from [voiceServiceProvider]. Recording goes through [AudioRecorder]
/// (press to start, release to score). Each clip is scored by [checkPair] and discarded
/// afterwards. Finishing the session saves the streak in the Coach store.
class DailySessionScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const DailySessionScreen({super.key});

  @override
  ConsumerState<DailySessionScreen> createState() => _DailySessionScreenState();
}

enum _Rec { idle, starting, recording, scoring }

class _DailySessionScreenState extends ConsumerState<DailySessionScreen> {
  late final AudioRecorder _recorder;
  late final VoiceService _voice;

  int _index = 0;
  bool _done = false;
  int? _streak;
  String? _saveProblem;

  _Rec _rec = _Rec.idle;
  bool _pressed = false;
  MicPermission? _blocked;
  bool _modelMissing = false;
  String? _message;
  PairVerdict? _verdict;

  bool _playing = false;
  int _speechGen = 0;

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(audioRecorderProvider);
    _voice = ref.read(voiceServiceProvider);
  }

  @override
  void dispose() {
    _speechGen++;
    unawaited(_voice.stop().catchError((Object _) {}));
    if (_rec == _Rec.starting || _rec == _Rec.recording) {
      unawaited(_recorder.cancel());
    }
    super.dispose();
  }

  void _set(VoidCallback change) {
    if (mounted) setState(change);
  }

  @override
  Widget build(BuildContext context) {
    final steps = ref.watch(dailySessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("Today's session")),
      body: steps.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => MessageView.error(
          onRetry: () => ref.invalidate(confusionsDataProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const MessageView(
              icon: Icons.hearing,
              title: 'Nothing to practise yet',
              message:
                  'Read a passage first. The session then uses the sounds you '
                  'find hardest.',
            );
          }
          if (_done) return _doneView(context);
          return _stepView(context, list);
        },
      ),
    );
  }

  Widget _doneView(BuildContext context) {
    final theme = Theme.of(context);
    final streak = _streak;
    return ReadingWidth(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Session done', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (streak != null)
              Text(
                streak == 0
                    ? 'Come back tomorrow to start a streak.'
                    : '$streak-day streak. Come back tomorrow to keep it going.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            if (_saveProblem != null) ...[
              const SizedBox(height: 8),
              Text(_saveProblem!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Back to Coach'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepView(BuildContext context, List<SessionStep> steps) {
    final theme = Theme.of(context);
    final step = steps[_index];
    final last = _index == steps.length - 1;
    return ReadingWidth(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          LinearProgressIndicator(value: _index / steps.length),
          const SizedBox(height: 8),
          Text(
            'Step ${_index + 1} of ${steps.length}',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 16),
          Text(step.instruction, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            step.isListen ? step.words.join('  ·  ') : step.target,
            style: theme.textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (step.isListen)
            Center(
              child: OutlinedButton.icon(
                onPressed: _playing ? null : () => unawaited(_playStep(step)),
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Play'),
              ),
            )
          else
            _sayControls(context, step),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _next(steps),
            child: Text(last ? 'Finish' : 'Next'),
          ),
        ],
      ),
    );
  }

  Widget _sayControls(BuildContext context, SessionStep step) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final verdict = _verdict;
    final recording = _rec == _Rec.recording;
    final scoring = _rec == _Rec.scoring;
    final label = switch (_rec) {
      _Rec.recording => "Release when you've finished",
      _Rec.scoring => 'Scoring...',
      _ => 'Hold to say "${step.target}"',
    };
    return Column(
      children: [
        Listener(
          onPointerDown: (_) => unawaited(_press(step)),
          onPointerUp: (_) => unawaited(_release(step)),
          onPointerCancel: (_) => unawaited(_release(step)),
          child: Semantics(
            button: true,
            label: label,
            child: Container(
              key: const Key('holdToSay'),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: recording ? scheme.error : scheme.primary,
              ),
              child: scoring
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: scheme.onPrimary,
                        strokeWidth: 3,
                      ),
                    )
                  : Icon(
                      recording ? Icons.mic : Icons.mic_none,
                      size: 36,
                      color: recording ? scheme.onError : scheme.onPrimary,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelLarge,
          textAlign: TextAlign.center,
        ),
        if (_blocked != null) ...[
          const SizedBox(height: 8),
          _PermissionPrompt(
            state: _blocked!,
            onAsk: _askPermission,
            onSettings: _recorder.openPermissionSettings,
          ),
        ] else if (_modelMissing) ...[
          const SizedBox(height: 8),
          Text(
            "The speech model isn't available on this phone yet, so the coach "
            "can't check your words. Try again after the app has finished "
            'setting up.',
            textAlign: TextAlign.center,
          ),
        ] else if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            key: const Key('sessionMessage'),
            textAlign: TextAlign.center,
          ),
        ],
        if (verdict != null) ...[
          const SizedBox(height: 12),
          _VerdictCard(sentence: _verdictSentence(verdict, step)),
        ],
      ],
    );
  }

  Future<void> _playStep(SessionStep step) async {
    final gen = ++_speechGen;
    _set(() => _playing = true);
    try {
      for (final word in step.words) {
        if (gen != _speechGen) return;
        await _voice.speak(word, rate: step.rate);
      }
    } on Object {
      // A voice failure just ends the playback; the button comes back.
    } finally {
      if (gen == _speechGen) _set(() => _playing = false);
    }
  }

  void _stopSpeech() {
    _speechGen++;
    unawaited(_voice.stop().catchError((Object _) {}));
  }

  void _next(List<SessionStep> steps) {
    _stopSpeech();
    if (_index + 1 >= steps.length) {
      _set(() => _done = true);
      unawaited(_finish());
      return;
    }
    _set(() {
      _index++;
      _playing = false;
      _verdict = null;
      _message = null;
      _blocked = null;
      _modelMissing = false;
    });
  }

  Future<void> _press(SessionStep step) async {
    if (_rec != _Rec.idle) return;
    _pressed = true;
    _set(() {
      _rec = _Rec.starting;
      _message = null;
      _verdict = null;
      _modelMissing = false;
    });
    try {
      final perm = await _recorder.checkPermission();
      if (perm != MicPermission.granted) {
        _set(() {
          _blocked = perm;
          _rec = _Rec.idle;
        });
        return;
      }
      await _recorder.start();
    } on MicPermissionException catch (e) {
      _set(() {
        _blocked = e.state;
        _rec = _Rec.idle;
      });
      return;
    } catch (_) {
      _set(() {
        _message = "Couldn't start the microphone. Please try again.";
        _rec = _Rec.idle;
      });
      return;
    }
    if (!mounted) {
      await _recorder.cancel();
      return;
    }
    _set(() {
      _blocked = null;
      _rec = _Rec.recording;
    });
    // Released before the recording started: score it now.
    if (!_pressed) await _score(step);
  }

  Future<void> _release(SessionStep step) async {
    _pressed = false;
    if (_rec == _Rec.recording) await _score(step);
  }

  Future<void> _score(SessionStep step) async {
    _set(() => _rec = _Rec.scoring);
    AudioClip? clip;
    try {
      clip = await _recorder.stop();
      final problem = _clipProblem(clip);
      if (problem != null) {
        _set(() {
          _message = problem;
          _rec = _Rec.idle;
        });
        return;
      }
      await _ensureModel();
      final verdict = await checkPair(
        clip,
        step.pair,
        recognizer: ref.read(phonemeRecognizerProvider),
        scorer: ref.read(pronunciationScorerProvider),
      );
      _set(() {
        _verdict = verdict;
        _rec = _Rec.idle;
      });
    } on ModelNotAvailableException {
      _set(() {
        _modelMissing = true;
        _rec = _Rec.idle;
      });
    } catch (_) {
      _set(() {
        _message = "Couldn't score that. Please try again.";
        _rec = _Rec.idle;
      });
    } finally {
      // Practice clips are never kept: delete once scored or rejected.
      final finished = clip;
      if (finished != null) unawaited(_discard(finished));
    }
  }

  /// Loads the tier the profile asks for, falling back to light. Throws
  /// [ModelNotAvailableException] when even the light model is missing.
  Future<void> _ensureModel() async {
    final recognizer = ref.read(phonemeRecognizerProvider);
    if (recognizer.loadedTier != null) return;
    final profile = await ref.read(progressRepositoryProvider).profile();
    final wanted = await preferredTier(recognizer, profile);
    try {
      await recognizer.load(wanted);
    } on ModelNotAvailableException {
      await recognizer.load(ModelTier.light);
    }
  }

  Future<void> _discard(AudioClip clip) async {
    try {
      await _recorder.discard(clip);
    } on Object {
      // Best effort: the file is app-private.
    }
  }

  Future<void> _askPermission() async {
    final state = await _recorder.requestPermission();
    _set(() => _blocked = state == MicPermission.granted ? null : state);
  }

  /// Saves the streak for today. The store and clock are read before any await so
  /// the write still completes if the screen is closed meanwhile.
  Future<void> _finish() async {
    final store = ref.read(coachStoreProvider);
    final clock = ref.read(clockProvider);
    final now = clock();
    try {
      final next = (await readSessionStreak(store)).recordedOn(now);
      await store.write(confusionsStoreKey, next.toJson());
      _set(() => _streak = next.currentAt(now));
    } on Object {
      _set(
        () => _saveProblem =
            "Your session is done, but the streak couldn't be saved.",
      );
    }
    if (mounted) ref.invalidate(confusionsDataProvider);
  }

  static String? _clipProblem(AudioClip clip) {
    if (clip.duration < _minSayClip) {
      return 'Hold the button down while you say the word.';
    }
    return switch (clip.quality) {
      AudioQuality.ok => null,
      AudioQuality.tooQuiet =>
        'That was too quiet. Hold the phone closer and speak up.',
      AudioQuality.tooNoisy =>
        "It's too noisy here. Try again somewhere quieter.",
    };
  }

  /// The estimate in plain words. It never claims a score.
  static String _verdictSentence(PairVerdict verdict, SessionStep step) {
    if (verdict.winner == PairWinner.ambiguous) {
      return 'Too close to call. Try once more, a little clearer.';
    }
    final matched = (verdict.winner == PairWinner.a) == step.sayA;
    if (matched) return "Sounds like '${step.target}'. Nice.";
    return "You said '${step.target}'; a listener may hear '${step.other}'.";
  }
}

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.sentence});

  final String sentence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sentence,
            key: const Key('verdictText'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimate from the on-device model, not a score.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({
    required this.state,
    required this.onAsk,
    required this.onSettings,
  });

  final MicPermission state;
  final Future<void> Function() onAsk;
  final Future<bool> Function() onSettings;

  @override
  Widget build(BuildContext context) {
    final permanent = state == MicPermission.permanentlyDenied;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          permanent
              ? 'The microphone is turned off for this app. Turn it on in Settings '
                    'to record. Recordings stay on your phone.'
              : 'The coach needs the microphone to hear you. Recordings stay on '
                    'your phone.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: permanent
              ? () => unawaited(onSettings())
              : () => unawaited(onAsk()),
          icon: Icon(permanent ? Icons.settings_outlined : Icons.mic_none),
          label: Text(permanent ? 'Open settings' : 'Allow microphone'),
        ),
      ],
    );
  }
}
