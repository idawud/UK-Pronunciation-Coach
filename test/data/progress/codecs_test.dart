import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/data/progress/codecs.dart';

void main() {
  group('DateTimeCodec', () {
    const c = DateTimeCodec();
    test('round-trips local, UTC and pre-1970 times exactly', () {
      for (final t in [
        DateTime(2026, 3, 29, 1, 30, 0, 1, 2),
        DateTime.utc(2026, 10, 25, 1, 0, 0, 0, 999),
        DateTime.utc(1960, 5, 6, 7),
        DateTime(1955, 1, 1),
      ]) {
        final back = c.fromSql(c.toSql(t));
        expect(back, t);
        expect(back.isUtc, t.isUtc);
      }
    });

    test('encoding keeps time order; bounds bracket both flags', () {
      final a = DateTime.utc(2026, 1, 1);
      final b = a.add(const Duration(microseconds: 1)).toLocal();
      expect(DateTimeCodec.encode(a), lessThan(DateTimeCodec.encode(b)));
      expect(DateTimeCodec.lowerBound(a), lessThanOrEqualTo(c.toSql(a)));
      expect(DateTimeCodec.upperBound(a), greaterThanOrEqualTo(c.toSql(a)));
      expect(
        DateTimeCodec.upperBound(a.toLocal()),
        DateTimeCodec.upperBound(a),
      );
    });
  });

  group('WordResultsCodec', () {
    const c = WordResultsCodec();
    const words = [
      WordResult(
        index: 0,
        text: 'Thursday',
        score: 41,
        status: WordStatus.fix,
        phonemes: [
          PhonemeResult(
            expected: 'θ',
            heard: 'f',
            score: 31,
            start: Duration(milliseconds: 120),
            end: Duration(milliseconds: 200),
          ),
          PhonemeResult(
            expected: 'ɜː',
            score: 90,
            start: Duration(milliseconds: 200),
            end: Duration(milliseconds: 260),
          ),
        ],
      ),
      WordResult(index: 1, text: 'naïve', score: 0, status: WordStatus.missed),
      WordResult(
        index: 7,
        text: 'x',
        score: -5,
        status: WordStatus.notScored,
        phonemes: [
          PhonemeResult(
            expected: 'θ',
            heard: 'θ',
            score: 100,
            start: Duration(microseconds: -1),
            end: Duration(days: 2),
          ),
        ],
      ),
    ];

    test('round-trips words, nulls, unicode and odd numbers', () {
      expect(c.fromSql(c.toSql(words)), words);
      expect(c.fromSql(c.toSql(const [])), isEmpty);
    });

    test('rejects unknown formats, statuses and corrupt bytes', () {
      final good = c.toSql(words);
      expect(
        () => c.fromSql(Uint8List.fromList([9, ...good.skip(1)])),
        throwsFormatException,
      );
      expect(
        () => c.fromSql(Uint8List.sublistView(good, 0, good.length - 1)),
        throwsFormatException,
      );
      expect(
        () => c.fromSql(Uint8List.fromList([...good, 0])),
        throwsFormatException,
      );
      expect(
        () => c.fromSql(Uint8List.fromList([1, 2, 1])),
        throwsFormatException,
      );
      // Format 1, one string "zz" used as a status.
      expect(
        () => c.fromSql(Uint8List.fromList([1, 1, 2, 122, 122, 1, 0, 0, 0])),
        throwsFormatException,
      );
    });
  });

  test('PhonemeSpecsCodec round-trips', () {
    const c = PhonemeSpecsCodec();
    const list = [PhonemeSpec(ipa: 'b'), PhonemeSpec(ipa: 'ɑː', stress: 1)];
    expect(c.fromSql(c.toSql(list)), list);
    expect(c.fromSql('[]'), isEmpty);
  });
}
