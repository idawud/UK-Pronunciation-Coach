import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';

/// Encodes to a JSON string and back, as storage and export do.
Map<String, dynamic> viaJson(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  final at = DateTime(2026, 10, 18, 9, 30);

  group('JSON round trip', () {
    final samples = <String, (Object, Object Function(Map<String, dynamic>))>{
      'PhonemeSpec': (
        const PhonemeSpec(ipa: 'ɑː', stress: 1),
        PhonemeSpec.fromJson,
      ),
      'WordSpec': (riverPassage.words[1], WordSpec.fromJson),
      'Passage': (riverPassage, Passage.fromJson),
      'AudioClip': (
        const AudioClip(
          path: '/a.wav',
          duration: Duration(milliseconds: 1234),
          quality: AudioQuality.tooNoisy,
          peakDbfs: -3.5,
          snrDb: 12,
        ),
        AudioClip.fromJson,
      ),
      'Segment': (
        const Segment(
          start: Duration(milliseconds: 150),
          end: Duration(milliseconds: 900),
        ),
        Segment.fromJson,
      ),
      'PhonemePosteriors': (
        syntheticPosteriors(teaPassage, tier: ModelTier.light),
        PhonemePosteriors.fromJson,
      ),
      'PhonemeResult': (
        cannedRiverAttempt.words[1].phonemes.first,
        PhonemeResult.fromJson,
      ),
      'WordResult': (cannedRiverAttempt.words[1], WordResult.fromJson),
      'AttemptResult': (
        cannedRiverAttempt.copyWith(audioPath: '/r.wav', tier: ModelTier.light),
        AttemptResult.fromJson,
      ),
      'SoundStat': (SoundStat.first('θ', 40, at), SoundStat.fromJson),
      'UserProfile': (
        UserProfile(
          level: 3,
          lastPractice: at,
          tierOverride: ModelTier.full,
          reminderMinutes: 600,
        ),
        UserProfile.fromJson,
      ),
      'LevelChange': (
        LevelChange(from: 2, to: 3, reason: 'Up', at: at),
        LevelChange.fromJson,
      ),
      'ReviewItem': (
        ReviewItem.enqueue(
          word: 'bath',
          phonemes: riverPassage.words[21].phonemes,
          now: at,
          score: 46,
          passageId: riverPassage.id,
        ),
        ReviewItem.fromJson,
      ),
      'PracticeSession': (
        PracticeSession(start: at, duration: const Duration(minutes: 7)),
        PracticeSession.fromJson,
      ),
      'DailyProgress': (
        DailyProgress(
          streak: 2,
          minutesToday: 5,
          dailyGoalMinutes: 10,
          practisedDays: [DateTime(2026, 10, 17), DateTime(2026, 10, 18)],
        ),
        DailyProgress.fromJson,
      ),
      'MinimalPair': (sampleMinimalPairs.first, MinimalPair.fromJson),
      'ModelDownloadProgress': (
        const ModelDownloadProgress(
          state: DownloadState.failed,
          receivedBytes: 10,
          totalBytes: 100,
          error: 'Checksum mismatch',
        ),
        ModelDownloadProgress.fromJson,
      ),
      'ProgressBackup': (
        ProgressBackup(
          exportedAt: at,
          profile: const UserProfile(level: 2),
          attempts: [cannedRiverAttempt],
          soundStats: [SoundStat.first('θ', 40, at)],
          reviewQueue: [ReviewItem.enqueue(word: 'bath', now: at)],
          levelHistory: [LevelChange(from: 1, to: 2, reason: 'Up', at: at)],
          practiceSessions: [
            PracticeSession(start: at, duration: const Duration(minutes: 3)),
          ],
        ),
        ProgressBackup.fromJson,
      ),
    };

    for (final MapEntry(key: name, value: (value, fromJson))
        in samples.entries) {
      test(name, () {
        final json = (value as dynamic).toJson() as Map<String, dynamic>;
        final back = fromJson(viaJson(json));
        expect(back, value);
        expect(back.hashCode, value.hashCode);
      });
    }

    test('defaults fill in missing optional fields', () {
      expect(
        WordSpec.fromJson({'text': 'a', 'index': 0}),
        const WordSpec(text: 'a', index: 0),
      );
      expect(UserProfile.fromJson({}), const UserProfile());
      expect(
        AudioClip.fromJson({'path': 'x', 'duration': 1000}).sampleRate,
        16000,
      );
    });
  });

  group('WordStatus', () {
    test('fromScore uses 80 / 60 by default', () {
      expect(WordStatus.fromScore(100), WordStatus.good);
      expect(WordStatus.fromScore(80), WordStatus.good);
      expect(WordStatus.fromScore(79), WordStatus.close);
      expect(WordStatus.fromScore(60), WordStatus.close);
      expect(WordStatus.fromScore(59), WordStatus.fix);
      expect(WordStatus.fromScore(0), WordStatus.fix);
      expect(WordStatus.fromScore(70, good: 70), WordStatus.good);
    });

    test('isRed', () {
      expect(WordStatus.values.where((s) => s.isRed), [
        WordStatus.fix,
        WordStatus.missed,
      ]);
    });
  });

  group('ReviewItem schedule', () {
    final now = DateTime(2026, 10, 18, 9);
    final item = ReviewItem.enqueue(word: 'Bath', now: now);

    test('enqueue is due one calendar day later', () {
      expect(item.key, 'bath');
      expect(item.stage, 0);
      expect(item.intervalDays, 1);
      expect(item.due, DateTime(2026, 10, 19, 9));
      expect(item.isDue(now), isFalse);
      expect(item.isDue(DateTime(2026, 10, 19, 9)), isTrue);
    });

    test('80+ advances 1 -> 3 -> 7 -> 21 days, then graduates', () {
      var r = item;
      for (final days in [3, 7, 21]) {
        r = r.afterScore(85, now)!;
        expect(r.intervalDays, days);
        expect(r.due, ReviewItem.addDays(now, days));
        expect(r.lastScore, 85);
      }
      expect(r.afterScore(90, now), isNull);
    });

    test('under 60 resets; 60-79 repeats the interval', () {
      final advanced = item.afterScore(90, now)!.afterScore(90, now)!;
      expect(advanced.stage, 2);
      final same = advanced.afterScore(70, now)!;
      expect(same.stage, 2);
      expect(same.intervalDays, 7);
      final reset = advanced.afterScore(30, now)!;
      expect(reset.stage, 0);
      expect(reset.intervalDays, 1);
      expect(reset.ease, closeTo(advanced.ease - 0.2, 1e-9));
    });

    test('ease never drops below 1.3', () {
      var r = item;
      for (var i = 0; i < 20; i++) {
        r = r.afterScore(10, now)!;
      }
      expect(r.ease, 1.3);
    });

    test('addDays keeps wall-clock time across the clock change', () {
      final t = DateTime(2026, 10, 24, 9);
      expect(ReviewItem.addDays(t, 1), DateTime(2026, 10, 25, 9));
      final u = DateTime.utc(2026, 10, 24, 9);
      expect(ReviewItem.addDays(u, 3), DateTime.utc(2026, 10, 27, 9));
    });
  });

  group('SoundStat', () {
    test('first and update follow the EMA rule', () {
      final s = SoundStat.first('θ', 40, DateTime(2026));
      expect(s.accuracy, 40);
      final u = s.update(80, DateTime(2027));
      expect(u.accuracy, closeTo(0.3 * 80 + 0.7 * 40, 1e-9));
      expect(u.attempts, 2);
      expect(u.lastPractised, DateTime(2027));
      expect(u.update(80, DateTime(2025)).lastPractised, DateTime(2027));
    });
  });

  group('Passage', () {
    test('sentenceRange splits at . ! ?', () {
      expect(riverPassage.sentenceRange(0), (start: 0, end: 7));
      expect(riverPassage.sentenceRange(6), (start: 0, end: 7));
      expect(riverPassage.sentenceRange(11), (start: 7, end: 15));
      expect(riverPassage.sentenceRange(26), (start: 15, end: 27));
      expect(() => riverPassage.sentenceRange(99), throwsRangeError);
    });

    test('without offsets the whole passage is one sentence', () {
      final p = riverPassage.copyWith(
        words: [for (final w in riverPassage.words) w.copyWith(offset: null)],
      );
      expect(p.sentenceRange(11), (start: 0, end: 27));
      expect(p.slice(1, 3).text, 'Thursday we');
    });

    test('slice re-indexes words and shifts offsets', () {
      final s = riverPassage.slice(7, 15);
      expect(s.id, '${riverPassage.id}#7-15');
      expect(s.text, 'We passed an old castle and a farm');
      expect(s.words.first.index, 0);
      for (final w in s.words) {
        expect(s.text.substring(w.offset!, w.offset! + w.text.length), w.text);
      }
      expect(s.words[4].text, 'castle');
      expect(riverPassage.slice(3, 3).words, isEmpty);
      expect(() => riverPassage.slice(5, 99), throwsRangeError);
    });
  });

  group('PhonemePosteriors', () {
    test('duration and frame times', () {
      final p = PhonemePosteriors(
        vocab: const ['<pad>', 'a'],
        frames: [Float32List(2), Float32List(2), Float32List(2)],
      );
      expect(p.duration, const Duration(milliseconds: 60));
      expect(p.frameStart(2), const Duration(milliseconds: 40));
      expect(p.blankIndex, 0);
      expect(p.tier, ModelTier.full);
    });
  });

  group('small helpers', () {
    test('ModelDownloadProgress fraction and isActive', () {
      expect(ModelDownloadProgress.idle.fraction, 0);
      expect(ModelDownloadProgress.idle.isActive, isFalse);
      const p = ModelDownloadProgress(
        state: DownloadState.downloading,
        receivedBytes: 25,
        totalBytes: 100,
      );
      expect(p.fraction, 0.25);
      expect(p.isActive, isTrue);
    });

    test('LevelChange.isUp, DailyProgress.goalMet, Segment.duration', () {
      expect(LevelChange(from: 1, to: 2, reason: '', at: at).isUp, isTrue);
      expect(LevelChange(from: 2, to: 1, reason: '', at: at).isUp, isFalse);
      expect(
        const DailyProgress(
          streak: 1,
          minutesToday: 10,
          dailyGoalMinutes: 10,
        ).goalMet,
        isTrue,
      );
      expect(
        const Segment(
          start: Duration(seconds: 1),
          end: Duration(seconds: 3),
        ).duration,
        const Duration(seconds: 2),
      );
    });
  });
}
