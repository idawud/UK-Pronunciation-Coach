// Fake-specific knobs that screens and tests rely on (beyond the shared contracts).
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';

void main() {
  group('FakeAudioRecorder', () {
    test('denied permission blocks start; settings can be opened', () async {
      final r = FakeAudioRecorder(
        permission: MicPermission.denied,
        permissionAfterRequest: MicPermission.denied,
      );
      await expectLater(r.start(), throwsA(isA<MicPermissionException>()));
      expect(await r.requestPermission(), MicPermission.denied);
      r.permission = MicPermission.permanentlyDenied;
      expect(await r.requestPermission(), MicPermission.permanentlyDenied);
      expect(await r.openPermissionSettings(), isTrue);
      expect(r.settingsOpened, 1);
      await r.dispose();
      await expectLater(r.start(), throwsStateError);
    });

    test('emits levels then silenceDetected', () {
      fakeAsync((async) {
        final r = FakeAudioRecorder(levels: [0.1, 0.5, 2.0]);
        final levels = <double>[];
        var silences = 0;
        r.level.listen(levels.add);
        r.silenceDetected.listen((_) => silences++);
        r.start();
        async.elapse(const Duration(milliseconds: 250));
        expect(levels, [0.1, 0.5, 1.0]);
        expect(silences, 1);
        r.stop();
      });
    });

    test('custom segments are clamped and sorted', () async {
      final r = FakeAudioRecorder(
        segments: const [
          Segment(start: Duration(seconds: 2), end: Duration(seconds: 9)),
          Segment(start: Duration(seconds: -1), end: Duration(seconds: 1)),
          Segment(start: Duration(seconds: 50), end: Duration(seconds: 60)),
        ],
        clip: const AudioClip(path: 'x', duration: Duration(seconds: 5)),
      );
      final s = await r.speechSegments(r.clip);
      expect(s, const [
        Segment(start: Duration.zero, end: Duration(seconds: 1)),
        Segment(start: Duration(seconds: 2), end: Duration(seconds: 5)),
      ]);
    });
  });

  group('FakePhonemeRecognizer', () {
    test('download failure and cancel', () async {
      final r = FakePhonemeRecognizer(failDownload: true);
      await expectLater(
        r.downloadFullModel(),
        throwsA(isA<ModelDownloadException>()),
      );
      expect(r.downloadStatus.state, DownloadState.failed);
      expect(r.downloadStatus.error, isNotEmpty);

      final c = FakePhonemeRecognizer(
        stepDelay: const Duration(milliseconds: 5),
      );
      final done = c.downloadFullModel();
      await Future<void>.delayed(const Duration(milliseconds: 7));
      await c.cancelDownload();
      await expectLater(done, throwsA(isA<ModelDownloadException>()));
      expect(c.downloadStatus.state, DownloadState.cancelled);
      expect(await c.isTierAvailable(ModelTier.full), isFalse);
    });

    test('already available full tier completes at once', () async {
      final r = FakePhonemeRecognizer(fullAvailable: true);
      await r.downloadFullModel();
      expect(r.downloadStatus.state, DownloadState.completed);
      await r.load(ModelTier.full);
      expect(r.loadedTier, ModelTier.full);
    });

    test('posteriors fit the clip and use the custom source', () async {
      final r = FakePhonemeRecognizer(
        posteriorsFor: (_) => syntheticPosteriors(teaPassage),
      );
      await r.load(ModelTier.light);
      final short = await r.recognise(
        const AudioClip(path: 'x', duration: Duration(milliseconds: 100)),
      );
      expect(short.frames, hasLength(5));
      expect(r.recogniseCount, 1);
    });
  });

  group('FakePronunciationScorer', () {
    test('river is canned; others are uniform; scoreWord cycles', () {
      final s = FakePronunciationScorer(wordScores: [40, 90]);
      final river = s.score(riverPassage, riverPosteriors, const []);
      expect(river.redWords.map((w) => w.text), ['Thursday', 'castle', 'bath']);
      final tea = s.score(
        teaPassage,
        syntheticPosteriors(teaPassage),
        const [],
      );
      expect(tea.words.every((w) => w.score == 90), isTrue);
      final word = riverPassage.words[1];
      final first = s.scoreWord(word, riverPosteriors);
      expect(first.status, WordStatus.fix);
      expect(first.phonemes.first.heard, 't');
      expect(s.scoreWord(word, riverPosteriors).status, WordStatus.good);
    });
  });

  group('FakeTips, FakeVoiceService', () {
    test('tips table', () {
      final t = FakeTips();
      expect(t.tipFor('ɑː', 'ɑːɹ'), contains("don't sound the r"));
      expect(t.tipFor('d', ''), isNotNull);
      expect(t.tipFor('p', 'b'), isNull);
    });

    test('voice records what was spoken', () async {
      final v = FakeVoiceService(britishVoice: false);
      await v.speak('bath', rate: VoiceService.slowRate);
      await v.speak('   ');
      expect(v.spoken, [('bath', 0.6)]);
      expect(await v.hasBritishVoice(), isFalse);
      expect(await v.voiceName(), isNull);
      await v.stop();
      expect(v.stopCount, 1);
    });
  });

  group('FakeContentRepository', () {
    test('custom passages and placement', () async {
      final c = FakeContentRepository(
        passages: [riverPassage],
        placement: [teaPassage],
      );
      expect((await c.all()).single, riverPassage);
      expect(await c.byId(teaPassage.id), teaPassage);
      expect((await c.lookup('the river')).every((w) => w.scorable), isTrue);
    });
  });

  group('FakePracticeEngine', () {
    test('nextPassage avoids recent passages and falls back', () async {
      final progress = FakeProgressRepository();
      final e = FakePracticeEngine(
        content: FakeContentRepository(),
        progress: progress,
      );
      expect((await e.nextPassage()).level, 1);
      await progress.saveAttempt(
        goodAttempt(teaPassage, id: 't', at: DateTime(2026)),
      );
      expect((await e.nextPassage()).id, teaPassage.id); // only one at level 1
      expect(samplePassages, contains(await e.nextPassage(soundTag: 'none')));
      expect(e.placementLevel(const []), 1);
    });

    test('a passing review graduates through the queue', () async {
      var now = DateTime(2026, 10, 1, 9);
      final progress = FakeProgressRepository(clock: () => now);
      final e = FakePracticeEngine(
        content: FakeContentRepository(),
        progress: progress,
        clock: () => now,
      );
      await e.recordAttempt(cannedRiverAttempt.copyWith(at: now));
      for (var i = 0; i < 4; i++) {
        now = now.add(const Duration(days: 30));
        await e.recordAttempt(
          goodAttempt(riverPassage, id: 'g$i', at: now, score: 95),
        );
      }
      expect(await progress.reviewQueue(), isEmpty);
    });
  });
}
