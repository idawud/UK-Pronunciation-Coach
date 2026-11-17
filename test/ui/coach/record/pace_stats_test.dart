import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/segment.dart';
import 'package:uk_pronunciation_coach/ui/coach/record/pace_stats.dart';

/// A raw VAD region for real speech from [startMs] to [endMs], padded the way
/// `AudioRecorder.speechSegments` pads it (150 ms each side).
Segment vad(int startMs, int endMs) => Segment(
  start: Duration(milliseconds: startMs - 150),
  end: Duration(milliseconds: endMs + 150),
);

void main() {
  group('paceStats', () {
    test('no pauses: one region gives its speaking time and a wpm', () {
      final stats = paceStats([vad(200, 1200)], 'one two three');
      expect(stats.speech, const Duration(milliseconds: 1000));
      expect(stats.words, 3);
      expect(stats.pauseCount, 0);
      expect(stats.longestPause, Duration.zero);
      expect(stats.wordsPerMinute, closeTo(180, 0.001));
    });

    test('a short gap of 300 ms is not a pause but is the longest gap', () {
      final stats = paceStats([vad(200, 1200), vad(1500, 2500)], 'a b');
      expect(stats.pauseCount, 0);
      expect(stats.longestPause, const Duration(milliseconds: 300));
    });

    test('a long gap of 1 s counts as one pause and is the longest', () {
      final stats = paceStats([vad(200, 1200), vad(2200, 3200)], 'a b c d');
      expect(stats.speech, const Duration(milliseconds: 2000));
      expect(stats.pauseCount, 1);
      expect(stats.longestPause, const Duration(seconds: 1));
      expect(stats.wordsPerMinute, closeTo(120, 0.001));
    });

    test('empty input gives no speech, no pauses and no wpm', () {
      final stats = paceStats(const [], 'hello there');
      expect(stats.speech, Duration.zero);
      expect(stats.pauseCount, 0);
      expect(stats.longestPause, Duration.zero);
      expect(stats.wordsPerMinute, isNull);
    });

    test('no typed words gives no wpm even with speech', () {
      final stats = paceStats([vad(200, 1200)], '   ');
      expect(stats.speech, const Duration(milliseconds: 1000));
      expect(stats.words, 0);
      expect(stats.wordsPerMinute, isNull);
    });
  });

  group('speechRegions', () {
    test('removes padding, sorts and drops regions that vanish', () {
      final regions = speechRegions([
        vad(1000, 2000),
        vad(200, 600),
        const Segment(
          start: Duration(milliseconds: 100),
          end: Duration(milliseconds: 200),
        ),
      ]);
      expect(regions.map((r) => r.start), [
        const Duration(milliseconds: 200),
        const Duration(milliseconds: 1000),
      ]);
      expect(regions.map((r) => r.end), [
        const Duration(milliseconds: 600),
        const Duration(milliseconds: 2000),
      ]);
    });
  });

  group('countWords', () {
    test('counts words, not punctuation', () {
      expect(countWords("Hurry up, or we'll miss the train."), 7);
      expect(countWords(''), 0);
    });
  });

  group('hints', () {
    test('pace hint follows the band', () {
      expect(paceHint(null), 'No speech heard yet.');
      expect(paceHint(90), startsWith('Slower'));
      expect(paceHint(130), startsWith('A natural'));
      expect(paceHint(200), startsWith('Quick'));
    });

    test('pause hint follows the count', () {
      PaceStats withPauses(int n) => PaceStats(
        speech: const Duration(seconds: 1),
        words: 1,
        pauseCount: n,
        longestPause: Duration.zero,
      );
      expect(pauseHint(withPauses(0)), startsWith('Smooth'));
      expect(pauseHint(withPauses(2)), isNot(startsWith('Many')));
      expect(pauseHint(withPauses(5)), startsWith('Many'));
    });
  });
}
