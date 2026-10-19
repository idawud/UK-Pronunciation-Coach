import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../../core/models/models.dart';

/// Stores a [DateTime] as one sortable integer: `microsecondsSinceEpoch * 2 + isUtc`.
///
/// Keeps the exact instant (microseconds) *and* whether the value was UTC or local, so
/// values read back compare equal (`DateTime ==` checks both), while `ORDER BY` and
/// range filters on the column still follow time order. Use [encode] for raw bounds.
class DateTimeCodec extends TypeConverter<DateTime, int> {
  /// Creates the codec.
  const DateTimeCodec();

  /// Encodes [t] for the database.
  static int encode(DateTime t) =>
      t.microsecondsSinceEpoch * 2 + (t.isUtc ? 1 : 0);

  /// Lowest stored value for an instant at or after [t] (local or UTC).
  static int lowerBound(DateTime t) => t.microsecondsSinceEpoch * 2;

  /// Highest stored value for an instant at or before [t] (local or UTC).
  static int upperBound(DateTime t) => t.microsecondsSinceEpoch * 2 + 1;

  /// Decodes a stored value.
  static DateTime decode(int v) =>
      DateTime.fromMicrosecondsSinceEpoch(v >> 1, isUtc: (v & 1) == 1);

  @override
  DateTime fromSql(int fromDb) => decode(fromDb);

  @override
  int toSql(DateTime value) => encode(value);
}

/// JSON for a review item's expected phonemes: `[[ipa, stress], ...]`.
class PhonemeSpecsCodec extends TypeConverter<List<PhonemeSpec>, String> {
  /// Creates the codec.
  const PhonemeSpecsCodec();

  @override
  List<PhonemeSpec> fromSql(String fromDb) => [
    for (final e in (jsonDecode(fromDb) as List<dynamic>).cast<List<dynamic>>())
      PhonemeSpec(ipa: e[0] as String, stress: e[1] as int),
  ];

  @override
  String toSql(List<PhonemeSpec> value) => jsonEncode([
    for (final p in value) [p.ipa, p.stress],
  ]);
}

/// Binary encoding of an attempt's words (with their phonemes), stored in one
/// `word_results` row per attempt.
///
/// One blob per attempt instead of one row per word keeps loading 1,000 attempts
/// (60,000 words, ~160,000 phonemes) well under 200 ms: a row per word cost over
/// 500 ms in SQLite row overhead alone, and JSON decoding another 250 ms.
///
/// Layout (format [format]); every integer is a zigzag varint:
///
/// ```text
/// format
/// stringCount, then per string: byteLength, UTF-8 bytes   (word texts, IPA, statuses)
/// wordCount, then per word:
///   index, score, statusRef, textRef, phonemeCount, then per phoneme:
///     expectedRef, heardRef + 1 (0 = null), score, startUs, endUs
/// ```
///
/// Statuses are stored by name, so reordering [WordStatus] cannot corrupt old rows.
/// To change the layout, add a new format number and keep decoding the old one.
class WordResultsCodec extends TypeConverter<List<WordResult>, Uint8List> {
  /// Creates the codec.
  const WordResultsCodec();

  /// Current layout version (first value of every blob).
  static const int format = 1;

  @override
  Uint8List toSql(List<WordResult> value) {
    final strings = <String, int>{};
    int ref(String s) => strings.putIfAbsent(s, () => strings.length);
    final body = _Writer()..uint(value.length);
    for (final w in value) {
      body
        ..sint(w.index)
        ..sint(w.score)
        ..uint(ref(w.status.name))
        ..uint(ref(w.text))
        ..uint(w.phonemes.length);
      for (final p in w.phonemes) {
        final heard = p.heard;
        body
          ..uint(ref(p.expected))
          ..uint(heard == null ? 0 : ref(heard) + 1)
          ..sint(p.score)
          ..sint(p.start.inMicroseconds)
          ..sint(p.end.inMicroseconds);
      }
    }
    final head = _Writer()
      ..uint(format)
      ..uint(strings.length);
    for (final s in strings.keys) {
      final bytes = utf8.encode(s);
      head
        ..uint(bytes.length)
        ..bytes(bytes);
    }
    return (BytesBuilder(copy: false)
          ..add(head.take())
          ..add(body.take()))
        .takeBytes();
  }

  @override
  List<WordResult> fromSql(Uint8List fromDb) {
    final r = _Reader(fromDb);
    final f = r.uint();
    if (f != format) {
      throw FormatException('Unknown word results format $f');
    }
    final strings = List<String>.generate(r.uint(), (_) => r.string());
    final statuses = {for (final s in WordStatus.values) s.name: s};
    final words = List<WordResult>.generate(r.uint(), (_) {
      final index = r.sint();
      final score = r.sint();
      final status = statuses[strings[r.uint()]];
      if (status == null) throw const FormatException('Unknown word status');
      final text = strings[r.uint()];
      final n = r.uint();
      final phonemes = n == 0
          ? const <PhonemeResult>[]
          : List<PhonemeResult>.generate(n, (_) {
              final expected = strings[r.uint()];
              final heard = r.uint();
              return PhonemeResult(
                expected: expected,
                heard: heard == 0 ? null : strings[heard - 1],
                score: r.sint(),
                start: Duration(microseconds: r.sint()),
                end: Duration(microseconds: r.sint()),
              );
            }, growable: false);
      return WordResult(
        index: index,
        text: text,
        score: score,
        phonemes: phonemes,
        status: status,
      );
    }, growable: false);
    if (!r.atEnd) throw const FormatException('Trailing word results bytes');
    return words;
  }
}

class _Writer {
  final _b = BytesBuilder();

  void uint(int v) {
    var x = v;
    while (x >= 0x80 || x < 0) {
      _b.addByte((x & 0x7f) | 0x80);
      x = x >>> 7;
    }
    _b.addByte(x);
  }

  void sint(int v) => uint((v << 1) ^ (v >> 63));

  void bytes(List<int> b) => _b.add(b);

  Uint8List take() => _b.takeBytes();
}

class _Reader {
  _Reader(this._b);

  final Uint8List _b;
  int _i = 0;

  bool get atEnd => _i == _b.length;

  int uint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_i >= _b.length) throw const FormatException('Truncated varint');
      final byte = _b[_i++];
      result |= (byte & 0x7f) << shift;
      if (byte < 0x80) return result;
      shift += 7;
    }
  }

  int sint() {
    final v = uint();
    return (v >>> 1) ^ -(v & 1);
  }

  String string() {
    final len = uint();
    if (_i + len > _b.length) throw const FormatException('Truncated string');
    final s = utf8.decode(Uint8List.sublistView(_b, _i, _i + len));
    _i += len;
    return s;
  }
}
