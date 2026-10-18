import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';

void main() {
  test('every provider returns a fake by default', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(useFakes, isTrue);
    expect(c.read(clockProvider)(), isA<DateTime>());
    expect(c.read(audioRecorderProvider), isA<FakeAudioRecorder>());
    expect(c.read(phonemeRecognizerProvider), isA<FakePhonemeRecognizer>());
    expect(c.read(pronunciationScorerProvider), isA<FakePronunciationScorer>());
    expect(c.read(tipsProvider), isA<FakeTips>());
    expect(c.read(contentRepositoryProvider), isA<FakeContentRepository>());
    expect(c.read(progressRepositoryProvider), isA<FakeProgressRepository>());
    expect(c.read(practiceEngineProvider), isA<FakePracticeEngine>());
    expect(c.read(voiceServiceProvider), isA<FakeVoiceService>());
  });

  test('userProfileProvider refreshes after a write', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final sub = c.listen(userProfileProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await c.read(userProfileProvider.future), const UserProfile());
    await c
        .read(progressRepositoryProvider)
        .saveProfile(const UserProfile(level: 4));
    await pumpEventQueue();
    expect((await c.read(userProfileProvider.future)).level, 4);
  });

  test('providers can be overridden in tests', () {
    final c = ProviderContainer(
      overrides: [
        audioRecorderProvider.overrideWithValue(
          FakeAudioRecorder(permission: MicPermission.denied),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(
      (c.read(audioRecorderProvider) as FakeAudioRecorder).permission,
      MicPermission.denied,
    );
  });
}
