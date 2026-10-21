/// The one place where contracts are bound to implementations (I1-integration).
///
/// The app uses the real implementations: A1 recorder, A2 ONNX recognizer, A3 scorer
/// and tips, C1 bundled content, C2 drift storage, C3 practice engine, C4 system
/// voice. Build with `--dart-define=USE_FAKES=true` to run the UI on the fakes in
/// lib/core/fakes/ instead (no microphone, model or database needed).
///
/// Two services need asynchronous set-up (opening the database, reading the model
/// manifest); [appStartupProvider] does it once and `CoachApp` shows a loading or
/// error screen until it completes. Every other provider is synchronous.
///
/// Screens read services only through these providers. Tests override them:
/// `ProviderScope(overrides: [audioRecorderProvider
/// .overrideWithValue(FakeAudioRecorder(permission: MicPermission.denied))], ...)`.
/// Unit and widget tests under test/ run with fakes by default
/// (test/flutter_test_config.dart sets [debugUseFakesOverride]).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content/bundled_content_repository.dart';
import '../data/progress/drift_progress_repository.dart';
import '../engine/audio/coach_audio_recorder.dart';
import '../engine/runtime/onnx_phoneme_recognizer.dart';
import '../engine/scoring/gop_pronunciation_scorer.dart';
import '../engine/scoring/table_tips.dart';
import '../practice/coach_practice_engine.dart';
import '../voice/voice.dart';
import 'contracts/contracts.dart';
import 'fakes/fakes.dart';
import 'models/models.dart';

/// `--dart-define=USE_FAKES=true`: bind every contract to its fake.
const bool useFakesDefine = bool.fromEnvironment('USE_FAKES');

/// Test hook: when set, overrides [useFakesDefine]. test/flutter_test_config.dart
/// sets it to true so unit and widget tests never reach a plug-in by accident.
@visibleForTesting
bool? debugUseFakesOverride;

/// True when the providers bind fakes instead of the real implementations.
bool get useFakes => debugUseFakesOverride ?? useFakesDefine;

/// Current time. Override in tests to move across midnight or clock changes.
final clockProvider = Provider<Clock>((ref) => systemClock);

/// Opens the local database (C2), with A1's recordings folder so "Delete all data"
/// also empties it.
final progressStoreProvider = FutureProvider<ProgressRepository>((ref) async {
  final repo = await DriftProgressRepository.open(
    recordingsDir: await defaultRecordingsDirectory(),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(repo.close);
  return repo;
}, retry: _noRetry);

/// Reads the model manifest and prepares the model folders (A2). The model itself
/// is loaded later, when the Read screen warms it up.
final recognizerStoreProvider = FutureProvider<PhonemeRecognizer>((ref) async {
  final recognizer = await OnnxPhonemeRecognizer.create();
  ref.onDispose(recognizer.dispose);
  return recognizer;
}, retry: _noRetry);

/// One-time asynchronous start-up: completes once the database is open and the
/// recognizer exists. `CoachApp` shows a loading screen until then, and an error
/// screen with "Try again" (which invalidates this provider) if it fails.
final appStartupProvider = FutureProvider<void>((ref) async {
  if (useFakes) return;
  await Future.wait([
    ref.watch(progressStoreProvider.future),
    ref.watch(recognizerStoreProvider.future),
  ]);
}, retry: _noRetry);

/// Start-up failures are shown with a "Try again" button instead of retried
/// silently in the background.
Duration? _noRetry(int retryCount, Object error) => null;

/// Microphone recording and speech detection (A1).
final audioRecorderProvider = Provider<AudioRecorder>((ref) {
  final recorder = useFakes
      ? FakeAudioRecorder()
      : CoachAudioRecorder.platform();
  ref.onDispose(recorder.dispose);
  return recorder;
});

/// On-device phoneme model (A2). The real one is ready after [appStartupProvider].
final phonemeRecognizerProvider = Provider<PhonemeRecognizer>((ref) {
  if (!useFakes) return ref.watch(recognizerStoreProvider).requireValue;
  final recognizer = FakePhonemeRecognizer();
  ref.onDispose(recognizer.dispose);
  return recognizer;
});

/// Alignment and scoring (A3), with I2's calibration (the config defaults).
final pronunciationScorerProvider = Provider<PronunciationScorer>(
  (ref) =>
      useFakes ? FakePronunciationScorer() : const GopPronunciationScorer(),
);

/// Pronunciation tips (A3).
final tipsProvider = Provider<Tips>(
  (ref) => useFakes ? FakeTips() : const TableTips(),
);

/// Passages and dictionary (C1).
final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => useFakes ? FakeContentRepository() : BundledContentRepository(),
);

/// Local storage (C2). The real one is ready after [appStartupProvider].
final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => useFakes
      ? FakeProgressRepository(clock: ref.watch(clockProvider))
      : ref.watch(progressStoreProvider).requireValue,
);

/// Practice logic (C3).
final practiceEngineProvider = Provider<PracticeEngine>(
  (ref) => useFakes
      ? FakePracticeEngine(
          content: ref.watch(contentRepositoryProvider),
          progress: ref.watch(progressRepositoryProvider),
          clock: ref.watch(clockProvider),
        )
      : CoachPracticeEngine(
          content: ref.watch(contentRepositoryProvider),
          progress: ref.watch(progressRepositoryProvider),
          clock: ref.watch(clockProvider),
        ),
);

/// British model voice (C4): the phone's offline en-GB voice (Piper only with
/// `--dart-define=PIPER_VOICE=true` and an engine, which v1 does not ship).
final voiceServiceProvider = Provider<VoiceService>((ref) {
  if (useFakes) return FakeVoiceService();
  final service = createVoiceService();
  ref.onDispose(service.stop);
  return service;
});

/// Ticks after every progress write; watch it to refresh derived data.
final progressChangesProvider = StreamProvider<void>(
  (ref) => ref.watch(progressRepositoryProvider).changes,
);

/// The user profile, refreshed after every progress write.
final userProfileProvider = FutureProvider<UserProfile>((ref) {
  ref.watch(progressChangesProvider);
  return ref.watch(progressRepositoryProvider).profile();
});

/// The model tier to score with: the Settings override, or for "Auto" the full
/// tier once it is downloaded (or while its download runs, so the Read screen can
/// show its progress) and the light tier otherwise.
///
/// I2 measured 3.6% native false red for the full tier and 7.1% for the light tier
/// (gate: < 5%), so the light tier shows word scores only (U2 / U3) and is never
/// preferred over a full model that is on the phone.
Future<ModelTier> preferredTier(
  PhonemeRecognizer recognizer,
  UserProfile profile,
) async {
  final override = profile.tierOverride;
  if (override != null) return override;
  if (recognizer.downloadStatus.isActive ||
      await recognizer.isTierAvailable(ModelTier.full)) {
    return ModelTier.full;
  }
  return ModelTier.light;
}
