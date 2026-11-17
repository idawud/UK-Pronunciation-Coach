import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/results/speech_segments.dart';

WordResult _w(int index, String text, WordStatus status) => WordResult(
  index: index,
  text: text,
  score: switch (status) {
    WordStatus.good => 90,
    WordStatus.close => 70,
    _ => 40,
  },
  status: status,
);

const _n = VoiceService.normalRate;
const _s = VoiceService.slowRate;

void main() {
  group('SpeechSegment', () {
    test('equality and hashCode use text and rate', () {
      const a = SpeechSegment('tea', 1.0);
      expect(a, const SpeechSegment('tea', 1.0));
      expect(a.hashCode, const SpeechSegment('tea', 1.0).hashCode);
      expect(a, isNot(const SpeechSegment('tea', 0.6)));
      expect(a, isNot(const SpeechSegment('cup', 1.0)));
      expect(a.toString(), 'SpeechSegment(tea, 1.0)');
    });
  });

  group('fullSentenceSegments', () {
    test('one segment at normal rate joining the words', () {
      final segments = fullSentenceSegments([
        _w(0, 'I', WordStatus.good),
        _w(1, 'like', WordStatus.fix),
        _w(2, 'tea', WordStatus.close),
      ]);
      expect(segments, [const SpeechSegment('I like tea', _n)]);
    });

    test('sorts by index and skips blank words', () {
      final segments = fullSentenceSegments([
        _w(2, 'tea', WordStatus.good),
        _w(1, ' ', WordStatus.good),
        _w(0, 'I', WordStatus.good),
      ]);
      expect(segments, [const SpeechSegment('I tea', _n)]);
    });

    test('no words gives no segments', () {
      expect(fullSentenceSegments(const []), isEmpty);
    });
  });

  group('stressedSegments', () {
    test('all good: one normal-rate segment', () {
      final segments = stressedSegments([
        _w(0, 'On', WordStatus.good),
        _w(1, 'Thursday', WordStatus.good),
      ]);
      expect(segments, [const SpeechSegment('On Thursday', _n)]);
    });

    test('mixed good, close, fix and missed merge by rate', () {
      final segments = stressedSegments([
        _w(0, 'we', WordStatus.good),
        _w(1, 'walked', WordStatus.close),
        _w(2, 'by', WordStatus.good),
        _w(3, 'the', WordStatus.good),
        _w(4, 'river', WordStatus.fix),
        _w(5, 'bath', WordStatus.missed),
        _w(6, 'and', WordStatus.good),
      ]);
      expect(segments, [
        const SpeechSegment('we', _n),
        const SpeechSegment('walked', _s),
        const SpeechSegment('by the', _n),
        const SpeechSegment('river bath', _s),
        const SpeechSegment('and', _n),
      ]);
    });

    test('all wrong: one slow segment', () {
      final segments = stressedSegments([
        _w(0, 'Thursday', WordStatus.fix),
        _w(1, 'castle', WordStatus.close),
      ]);
      expect(segments, [const SpeechSegment('Thursday castle', _s)]);
    });

    test('consecutive wrong words merge into one slow segment', () {
      final segments = stressedSegments([
        _w(0, 'a', WordStatus.good),
        _w(1, 'castle', WordStatus.fix),
        _w(2, 'and', WordStatus.close),
        _w(3, 'farm', WordStatus.fix),
        _w(4, 'end', WordStatus.good),
      ]);
      expect(segments, [
        const SpeechSegment('a', _n),
        const SpeechSegment('castle and farm', _s),
        const SpeechSegment('end', _n),
      ]);
    });

    test('empty input gives no segments', () {
      expect(stressedSegments(const []), isEmpty);
    });

    test('unsorted input is played in index order', () {
      final segments = stressedSegments([
        _w(2, 'tea', WordStatus.good),
        _w(0, 'I', WordStatus.fix),
        _w(1, 'like', WordStatus.good),
      ]);
      expect(segments, [
        const SpeechSegment('I', _s),
        const SpeechSegment('like tea', _n),
      ]);
    });

    test('blank words are skipped without splitting a merge', () {
      final segments = stressedSegments([
        _w(0, 'a', WordStatus.good),
        _w(1, '', WordStatus.fix),
        _w(2, 'b', WordStatus.good),
      ]);
      expect(segments, [const SpeechSegment('a b', _n)]);
    });
  });

  group('wrongWordsSegments', () {
    test('none wrong gives an empty list', () {
      expect(
        wrongWordsSegments([
          _w(0, 'a', WordStatus.good),
          _w(1, 'b', WordStatus.good),
        ]),
        isEmpty,
      );
    });

    test('one wrong word gives one slow segment', () {
      expect(
        wrongWordsSegments([
          _w(0, 'a', WordStatus.good),
          _w(1, 'bath', WordStatus.fix),
        ]),
        [const SpeechSegment('bath', _s)],
      );
    });

    test('many wrong words each get their own segment, in order', () {
      final segments = wrongWordsSegments([
        _w(3, 'river', WordStatus.close),
        _w(0, 'Thursday', WordStatus.fix),
        _w(1, 'ok', WordStatus.good),
        _w(2, 'castle', WordStatus.missed),
      ]);
      expect(segments, [
        const SpeechSegment('Thursday', _s),
        const SpeechSegment('castle', _s),
        const SpeechSegment('river', _s),
      ]);
    });
  });
}
