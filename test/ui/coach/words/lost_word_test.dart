import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/ui/coach/words/lost_word.dart';

void main() {
  final added = DateTime(2026, 10, 19, 9, 30, 15, 250);
  final due = DateTime(2026, 10, 20, 9, 30);

  test('JSON round trip keeps every field, with a note', () {
    final w = LostWord(
      word: 'scaffold',
      note: 'the thing that holds up the building',
      addedAt: added,
      due: due,
      box: 3,
      lapses: 2,
    );
    final back = LostWord.fromJson(w.toJson());
    expect(back, w);
    expect(back.note, 'the thing that holds up the building');
    expect(back.box, 3);
    expect(back.lapses, 2);
  });

  test('a null note is left out of the JSON and comes back null', () {
    final w = LostWord(word: 'quay', addedAt: added, due: due);
    final json = w.toJson();
    expect(json.containsKey('note'), isFalse);
    expect(LostWord.fromJson(json).note, isNull);
  });

  test('dates are stored as UTC and read back as the same instant', () {
    final json = LostWord(word: 'quay', addedAt: added, due: due).toJson();
    expect(json['addedAt'], endsWith('Z'));
    expect(LostWord.fromJson(json).addedAt.isAtSameMomentAs(added), isTrue);
  });

  test('box and lapses are clamped on read', () {
    final json = LostWord(word: 'quay', addedAt: added, due: due).toJson()
      ..['box'] = 9
      ..['lapses'] = -4;
    final back = LostWord.fromJson(json);
    expect(back.box, 5);
    expect(back.lapses, 0);
    expect(LostWord.fromJson({...json, 'box': 0}).box, 1);
  });

  test('keyOf trims and lower-cases', () {
    expect(LostWord.keyOf('  Scaffold  '), 'scaffold');
  });

  test('fromJson throws FormatException on bad or missing fields', () {
    final good = LostWord(word: 'quay', addedAt: added, due: due).toJson();
    final noWord = Map<String, Object?>.of(good)..remove('word');
    expect(() => LostWord.fromJson(noWord), throwsFormatException);
    expect(
      () => LostWord.fromJson({...good, 'word': '   '}),
      throwsFormatException,
    );
    expect(
      () => LostWord.fromJson({...good, 'due': 'next tuesday'}),
      throwsFormatException,
    );
    expect(
      () => LostWord.fromJson({...good, 'box': '2'}),
      throwsFormatException,
    );
  });
}
