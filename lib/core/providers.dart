/// The one place where contracts are bound to implementations.
///
/// Every provider returns a fake from lib/core/fakes/ until I1-integration swaps in the
/// real implementations here (keeping fakes behind `--dart-define=USE_FAKES=true`).
/// Screens read services only through these providers, so the swap touches no screen.
/// Tests override them: `ProviderScope(overrides: [audioRecorderProvider
/// .overrideWithValue(FakeAudioRecorder(permission: MicPermission.denied))], ...)`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'contracts/contracts.dart';
import 'fakes/fakes.dart';
import 'models/models.dart';

/// True when the app should use fakes (always true until I1 wires real
/// implementations). Set with `--dart-define=USE_FAKES=true`.
const bool useFakes = bool.fromEnvironment('USE_FAKES', defaultValue: true);

/// Current time. Override in tests to move across midnight or clock changes.
final clockProvider = Provider<Clock>((ref) => systemClock);

/// Microphone recording and speech detection (A1).
final audioRecorderProvider = Provider<AudioRecorder>((ref) {
  final recorder = FakeAudioRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});

/// On-device phoneme model (A2).
final phonemeRecognizerProvider = Provider<PhonemeRecognizer>((ref) {
  final recognizer = FakePhonemeRecognizer();
  ref.onDispose(recognizer.dispose);
  return recognizer;
});

/// Alignment and scoring (A3).
final pronunciationScorerProvider = Provider<PronunciationScorer>(
  (ref) => FakePronunciationScorer(),
);

/// Pronunciation tips (A3).
final tipsProvider = Provider<Tips>((ref) => FakeTips());

/// Passages and dictionary (C1).
final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => FakeContentRepository(),
);

/// Local storage (C2).
final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => FakeProgressRepository(clock: ref.watch(clockProvider)),
);

/// Practice logic (C3).
final practiceEngineProvider = Provider<PracticeEngine>(
  (ref) => FakePracticeEngine(
    content: ref.watch(contentRepositoryProvider),
    progress: ref.watch(progressRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// British model voice (C4).
final voiceServiceProvider = Provider<VoiceService>(
  (ref) => FakeVoiceService(),
);

/// Ticks after every progress write; watch it to refresh derived data.
final progressChangesProvider = StreamProvider<void>(
  (ref) => ref.watch(progressRepositoryProvider).changes,
);

/// The user profile, refreshed after every progress write.
final userProfileProvider = FutureProvider<UserProfile>((ref) {
  ref.watch(progressChangesProvider);
  return ref.watch(progressRepositoryProvider).profile();
});
