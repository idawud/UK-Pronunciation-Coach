import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/practice/review_updates.dart';

void main() {
  final now = DateTime.utc(2026, 10, 18, 9);
  final ph = parseIpa('θ ˈɜː z d eɪ');

  WordResult word(
    String text,
    int score, {
    WordStatus? status,
    int index = 0,
  }) => WordResult(
    index: index,
    text: text,
    score: score,
    status: status ?? WordStatus.fromScore(score),
  );

  ReviewUpdates run(
    List<WordResult> words, [
    List<ReviewItem> queue = const [],
  ]) => reviewUpdatesFor(
    words: words,
    queue: {for (final q in queue) q.key: q},
    now: now,
    passageId: 'p1',
    phonemesFor: (_) => ph,
  );

  test('red and missed words are enqueued at stage 0, due in 1 day', () {
    final u = run([
      word('Thursday', 40),
      word('castle', 0, status: WordStatus.missed),
      word('river', 70),
      word('the', 95),
      word('Zog', 0, status: WordStatus.notScored),
    ]);
    expect(u.removals, isEmpty);
    expect(u.upserts.map((r) => r.word), ['Thursday', 'castle']);
    final t = u.upserts.first;
    expect(t.stage, 0);
    expect(t.intervalDays, 1);
    expect(t.due, DateTime.utc(2026, 10, 19, 9));
    expect(t.phonemes, ph);
    expect(t.passageId, 'p1');
    expect(t.lastScore, 40);
  });

  test(
    'a word repeated in one attempt is handled once, by its worst score',
    () {
      final u = run([
        word('a', 90),
        word('A', 30, index: 1),
        word('a', 85, index: 2),
      ]);
      expect(u.upserts, hasLength(1));
      expect(u.upserts.single.lastScore, 30);
    },
  );

  // Uses the shared ReviewItem.afterScore rule: (stage, score) -> new stage or removed.
  final cases = <(String, int, int, int?)>[
    ('80+ advances 1 -> 3 days', 0, 85, 1),
    ('80+ advances 3 -> 7 days', 1, 80, 2),
    ('80+ advances 7 -> 21 days', 2, 99, 3),
    ('80+ at 21 days graduates', 3, 90, null),
    ('60-79 repeats the interval', 2, 70, 2),
    ('under 60 resets', 3, 59, 0),
  ];
  for (final (name, stage, score, expected) in cases) {
    test(name, () {
      final queued = ReviewItem(
        word: 'Castle',
        due: now,
        intervalDays: ReviewItem.intervals[stage],
        stage: stage,
      );
      final u = run([word('castle', score)], [queued]);
      if (expected == null) {
        expect(u.upserts, isEmpty);
        expect(u.removals, ['Castle']);
      } else {
        final r = u.upserts.single;
        expect(r.stage, expected);
        expect(r.intervalDays, ReviewItem.intervals[expected]);
        expect(r.due, ReviewItem.addDays(now, ReviewItem.intervals[expected]));
        expect(u.removals, isEmpty);
      }
    });
  }
}
