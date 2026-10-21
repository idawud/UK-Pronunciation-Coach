import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/data/content/bundled_content_repository.dart';
import 'package:uk_pronunciation_coach/data/progress/drift_progress_repository.dart';
import 'package:uk_pronunciation_coach/engine/audio/coach_audio_recorder.dart';
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';
import 'package:uk_pronunciation_coach/practice/coach_practice_engine.dart';
import 'package:uk_pronunciation_coach/voice/system_voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the app build uses the real implementations', () {
    expect(useFakesDefine, isFalse);
  });

  group('with fakes (the default under test/)', () {
    test('every provider returns a fake', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(useFakes, isTrue);
      await c.read(appStartupProvider.future);
      expect(c.read(clockProvider)(), isA<DateTime>());
      expect(c.read(audioRecorderProvider), isA<FakeAudioRecorder>());
      expect(c.read(phonemeRecognizerProvider), isA<FakePhonemeRecognizer>());
      expect(
        c.read(pronunciationScorerProvider),
        isA<FakePronunciationScorer>(),
      );
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
  });

  group('real implementations', () {
    // The recorder and voice talk to plug-ins when disposed; answer them.
    const channels = [
      MethodChannel('com.llfbandit.record/messages'),
      MethodChannel('flutter_tts'),
    ];
    setUp(() {
      debugUseFakesOverride = false;
      for (final ch in channels) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ch, (_) async => null);
      }
    });
    // The mocks stay for the rest of this file: disposal finishes asynchronously.
    tearDown(() => debugUseFakesOverride = true);

    test('bind every contract once start-up has finished', () async {
      final store = DriftProgressRepository.inMemory();
      final recognizer = FakePhonemeRecognizer();
      final c = ProviderContainer(
        overrides: [
          progressStoreProvider.overrideWith((ref) async => store),
          recognizerStoreProvider.overrideWith((ref) async => recognizer),
        ],
      );
      addTearDown(() async {
        c.dispose();
        await store.close();
      });
      await c.read(appStartupProvider.future);
      expect(c.read(progressRepositoryProvider), same(store));
      expect(c.read(phonemeRecognizerProvider), same(recognizer));
      expect(c.read(audioRecorderProvider), isA<CoachAudioRecorder>());
      expect(
        c.read(pronunciationScorerProvider),
        isA<GopPronunciationScorer>(),
      );
      expect(c.read(tipsProvider), isA<TableTips>());
      expect(
        c.read(contentRepositoryProvider),
        isA<BundledContentRepository>(),
      );
      expect(c.read(practiceEngineProvider), isA<CoachPracticeEngine>());
      expect(c.read(voiceServiceProvider), isA<SystemVoiceService>());
    });

    test('a failed start-up is reported and can be retried', () async {
      var fail = true;
      final store = DriftProgressRepository.inMemory();
      final c = ProviderContainer(
        overrides: [
          progressStoreProvider.overrideWith((ref) async {
            if (fail) throw StateError('disk full');
            return store;
          }),
          recognizerStoreProvider.overrideWith(
            (ref) async => FakePhonemeRecognizer(),
          ),
        ],
      );
      addTearDown(() async {
        c.dispose();
        await store.close();
      });
      final sub = c.listen(appStartupProvider, (_, _) {});
      addTearDown(sub.close);
      await expectLater(
        c.read(appStartupProvider.future),
        throwsA(isA<StateError>()),
      );
      fail = false;
      c.invalidate(progressStoreProvider);
      c.invalidate(appStartupProvider);
      await c.read(appStartupProvider.future);
      expect(c.read(progressRepositoryProvider), same(store));
    });
  });

  group('preferredTier (Auto)', () {
    test('an override always wins', () async {
      final r = FakePhonemeRecognizer(fullAvailable: true);
      expect(
        await preferredTier(
          r,
          const UserProfile(tierOverride: ModelTier.light),
        ),
        ModelTier.light,
      );
      expect(
        await preferredTier(
          FakePhonemeRecognizer(),
          const UserProfile(tierOverride: ModelTier.full),
        ),
        ModelTier.full,
      );
    });

    test(
      'Auto: full once downloaded, even where light is recommended',
      () async {
        expect(
          await preferredTier(
            FakePhonemeRecognizer(
              recommended: ModelTier.light,
              fullAvailable: true,
            ),
            const UserProfile(),
          ),
          ModelTier.full,
        );
      },
    );

    test('Auto: light before the download, full while it runs', () async {
      final r = FakePhonemeRecognizer(
        stepDelay: const Duration(milliseconds: 20),
      );
      expect(await preferredTier(r, const UserProfile()), ModelTier.light);
      final running = r.downloadFullModel();
      while (!r.downloadStatus.isActive) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(await preferredTier(r, const UserProfile()), ModelTier.full);
      await running;
      expect(await preferredTier(r, const UserProfile()), ModelTier.full);
    });
  });
}
