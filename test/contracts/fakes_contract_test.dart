// Runs every shared contract suite against the fakes in lib/core/fakes/.
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';

import 'audio_recorder_contract.dart';
import 'content_repository_contract.dart';
import 'phoneme_recognizer_contract.dart';
import 'practice_engine_contract.dart';
import 'progress_repository_contract.dart';
import 'pronunciation_scorer_contract.dart';
import 'tips_contract.dart';
import 'voice_service_contract.dart';

void main() {
  group('FakeAudioRecorder', () {
    runAudioRecorderContract(
      () async =>
          FakeAudioRecorder(levelInterval: const Duration(milliseconds: 20)),
    );
  });

  group('FakePhonemeRecognizer', () {
    runPhonemeRecognizerContract(
      () async => FakePhonemeRecognizer(),
      clip: AudioClip(
        path: 'test/fixtures/audio/clean_read.wav',
        duration: riverPosteriors.duration,
      ),
    );
  });

  group('FakePronunciationScorer', () {
    runPronunciationScorerContract(
      FakePronunciationScorer.new,
      checkSemantics: false,
    );
  });

  group('FakeTips', () {
    runTipsContract(FakeTips.new);
  });

  group('FakeContentRepository', () {
    runContentRepositoryContract(
      () async => FakeContentRepository(),
      fullLibrary: false,
    );
  });

  group('FakeProgressRepository', () {
    runProgressRepositoryContract(
      (clock) async => FakeProgressRepository(clock: clock),
    );
  });

  group('FakePracticeEngine', () {
    runPracticeEngineContract(
      (clock) async => FakePracticeEngine(
        content: FakeContentRepository(),
        progress: FakeProgressRepository(clock: clock),
        clock: clock,
      ),
    );
  });

  group('FakeVoiceService', () {
    runVoiceServiceContract(() async => FakeVoiceService());
  });
}
