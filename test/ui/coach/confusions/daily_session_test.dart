import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/coach/confusions/confusion_logic.dart';
import 'package:uk_pronunciation_coach/ui/coach/confusions/daily_session.dart';

import 'confusion_fixtures.dart';

/// A confusion of [expected] heard as [heard].
Confusion swap(String expected, String heard) =>
    Confusion(expected: expected, heard: heard, count: 3, avgScore: 40);

const MinimalPair ship = MinimalPair(
  contrast: 'ɪ-iː',
  wordA: 'ship',
  wordB: 'sheep',
  phonemesA: [
    PhonemeSpec(ipa: 'ʃ'),
    PhonemeSpec(ipa: 'ɪ', stress: 1),
  ],
  phonemesB: [
    PhonemeSpec(ipa: 'ʃ'),
    PhonemeSpec(ipa: 'iː', stress: 1),
  ],
);

const MinimalPair luck = MinimalPair(
  contrast: 'ʌ-ɑː',
  wordA: 'luck',
  wordB: 'lark',
  phonemesA: [
    PhonemeSpec(ipa: 'l'),
    PhonemeSpec(ipa: 'ʌ', stress: 1),
  ],
  phonemesB: [
    PhonemeSpec(ipa: 'l'),
    PhonemeSpec(ipa: 'ɑː', stress: 1),
  ],
);

void main() {
  group('buildDailySession', () {
    test('a matched confusion gives 8 steps for the default 5 minutes', () {
      final steps = buildDailySession([swap('ʌ', 'æ')], [catCut]);
      expect(steps, hasLength(8));
    });

    test('matches the contrast in either order', () {
      // Pair written æ-ʌ, confusion ʌ heard as æ.
      final forward = buildDailySession([swap('ʌ', 'æ')], [catCut]);
      expect(forward.first.pair, catCut);

      // Same pair written ʌ-æ, confusion æ heard as ʌ.
      final reversed = MinimalPair(
        contrast: 'ʌ-æ',
        wordA: 'cut',
        wordB: 'cat',
        phonemesA: catCut.phonemesB,
        phonemesB: catCut.phonemesA,
      );
      final backward = buildDailySession([swap('æ', 'ʌ')], [reversed]);
      expect(backward.first.pair, reversed);
      expect(backward, hasLength(8));
    });

    test('a pair that does not match the confusion is not used', () {
      final steps = buildDailySession([swap('ʌ', 'æ')], [ship]);
      expect(steps, isEmpty);
    });

    test('size stays within 8 to 12 steps across pair counts and minutes', () {
      final confusions = [swap('ʌ', 'æ'), swap('ɪ', 'iː'), swap('ʌ', 'ɑː')];
      final pairs = [catCut, ship, luck];
      for (final minutes in [5, 10]) {
        for (var n = 1; n <= pairs.length; n++) {
          final steps = buildDailySession(
            confusions.take(n).toList(),
            pairs.take(n).toList(),
            minutes: minutes,
          );
          expect(
            steps.length,
            inInclusiveRange(8, 12),
            reason: 'minutes $minutes, $n pairs',
          );
        }
      }
    });

    test('three pairs give 12 steps from 8 minutes', () {
      final steps = buildDailySession(
        [swap('ʌ', 'æ'), swap('ɪ', 'iː'), swap('ʌ', 'ɑː')],
        [catCut, ship, luck],
        minutes: 8,
      );
      expect(steps, hasLength(12));
    });

    test('each pair runs listen slow, listen normal, say A, say B', () {
      final steps = buildDailySession([swap('ʌ', 'æ')], [catCut]);
      final firstFour = steps.take(4).toList();
      expect(
        [for (final s in firstFour) s.kind],
        [
          SessionStepKind.listenSlow,
          SessionStepKind.listenNormal,
          SessionStepKind.say,
          SessionStepKind.say,
        ],
      );
      expect(firstFour[0].words, ['cat', 'cut']);
      expect(firstFour[0].rate, VoiceService.slowRate);
      expect(firstFour[1].rate, VoiceService.normalRate);
      expect(firstFour[2].target, 'cat');
      expect(firstFour[2].other, 'cut');
      expect(firstFour[3].target, 'cut');
      expect(firstFour[3].other, 'cat');
      for (final s in steps) {
        expect(s.instruction, isNotEmpty);
      }
    });

    test('a single pair is repeated so the session still has 8 steps', () {
      final steps = buildDailySession([swap('ʌ', 'æ')], [catCut]);
      expect(
        [for (final s in steps.take(4)) s.kind],
        [for (final s in steps.skip(4)) s.kind],
      );
    });

    test('no confusions and no sound stats uses the pairs in order', () {
      final steps = buildDailySession(const [], [ship, catCut]);
      expect(steps.first.pair, ship);
      expect(steps, hasLength(8));
    });

    test('fallback without confusions seeds from the weakest sounds', () {
      final stats = [
        SoundStat(
          ipa: 'ɪ',
          accuracy: 80,
          attempts: 4,
          lastPractised: DateTime(2026),
        ),
        SoundStat(
          ipa: 'ʌ',
          accuracy: 20,
          attempts: 4,
          lastPractised: DateTime(2026),
        ),
        // Never practised: ignored even though it is listed.
        SoundStat(
          ipa: 'ɑː',
          accuracy: 0,
          attempts: 0,
          lastPractised: DateTime(2026),
        ),
      ];
      // ship/sheep comes first in the list, but ʌ is the weakest sound.
      final steps = buildDailySession(const [], [
        ship,
        catCut,
      ], soundStats: stats);
      expect(steps.first.pair, catCut);
      expect(steps.first.pair.contrast, 'æ-ʌ');
    });

    test('no pairs gives an empty session', () {
      expect(buildDailySession([swap('ʌ', 'æ')], const []), isEmpty);
      expect(buildDailySession(const [], const []), isEmpty);
    });

    test('a confusion without a matching pair falls back to weak sounds', () {
      final steps = buildDailySession(
        [swap('θ', 'f')],
        [luck],
        soundStats: [
          SoundStat(
            ipa: 'ʌ',
            accuracy: 30,
            attempts: 2,
            lastPractised: DateTime(2026),
          ),
        ],
      );
      expect(steps.first.pair, luck);
    });

    test('confusions come before weak-sound pairs', () {
      final steps = buildDailySession(
        [swap('ɪ', 'iː')],
        [catCut, ship],
        soundStats: [
          SoundStat(
            ipa: 'ʌ',
            accuracy: 10,
            attempts: 2,
            lastPractised: DateTime(2026),
          ),
        ],
      );
      expect(steps.first.pair, ship);
    });

    test('pairs are not repeated within one round', () {
      final steps = buildDailySession(
        [swap('ʌ', 'æ'), swap('ʌ', 'æ')],
        [catCut, catCut],
        minutes: 8,
      );
      final distinct = {for (final s in steps) s.pair.wordA + s.pair.wordB};
      expect(distinct, hasLength(1));
      expect(steps.length, 8);
    });
  });

  group('SessionStreak', () {
    final today = DateTime(2026, 10, 19, 9);

    test('the first session starts a streak at 1', () {
      final next = const SessionStreak().recordedOn(today);
      expect(next.streak, 1);
      expect(next.lastSessionDate, '2026-10-19');
    });

    test('a second session on the same day changes nothing', () {
      final once = const SessionStreak().recordedOn(today);
      expect(once.recordedOn(DateTime(2026, 10, 19, 20)), same(once));
    });

    test('the day after extends the streak', () {
      final s = SessionStreak.fromJson({
        'lastSessionDate': '2026-10-18',
        'streak': 4,
      });
      expect(s.recordedOn(today).streak, 5);
    });

    test('a gap restarts the streak at 1', () {
      final s = SessionStreak.fromJson({
        'lastSessionDate': '2026-10-15',
        'streak': 4,
      });
      expect(s.recordedOn(today).streak, 1);
    });

    test('the streak carries across a month boundary', () {
      final s = SessionStreak.fromJson({
        'lastSessionDate': '2026-09-30',
        'streak': 2,
      });
      expect(s.recordedOn(DateTime(2026, 10, 1)).streak, 3);
    });

    test('currentAt shows the streak only when last session was today or yesterday', () {
      final s = SessionStreak.fromJson({
        'lastSessionDate': '2026-10-18',
        'streak': 4,
      });
      expect(s.currentAt(today), 4);
      expect(s.currentAt(DateTime(2026, 10, 20)), 0);
      expect(const SessionStreak().currentAt(today), 0);
    });

    test('malformed stored values count as no streak', () {
      expect(SessionStreak.fromJson(null).streak, 0);
      final bad = SessionStreak.fromJson({
        'lastSessionDate': 42,
        'streak': 'four',
      });
      expect(bad.lastSessionDate, isNull);
      expect(bad.streak, 0);
    });

    test('dayKey pads month and day', () {
      expect(SessionStreak.dayKey(DateTime(2026, 3, 4)), '2026-03-04');
    });

    test('round-trips through toJson', () {
      final s = const SessionStreak().recordedOn(today);
      final back = SessionStreak.fromJson(s.toJson());
      expect(back.lastSessionDate, s.lastSessionDate);
      expect(back.streak, s.streak);
    });
  });
}
