import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/data/content/britfone_lexicon.dart';

const _table = '''
# comment
the\tð ə|ð i|ð ˈiː
to\tt ə|t ʊ|t ˈuː
for\tf ə|f ˈɔː
apple\tˈæ p ə l
cat\tk ˈæ t
wash\tw ˈɒ ʃ
bus\tb ˈʌ s
dog\td ˈɒ ɡ
want\tw ˈɒ n t
play\tp l ˈeɪ
skip\ts k ˈɪ p
make\tm ˈeɪ k
run\tɹ ˈʌ n
fly\tf l ˈaɪ
i\tˈaɪ
it\tɪ t|ˈɪ t
that\tð ˈæ t|ð ə t
bad line without a tab
''';

String ipa(List<PhonemeSpec> ps) => [
  for (final p in ps)
    '${p.stress == 1 ? 'ˈ' : (p.stress == 2 ? 'ˌ' : '')}${p.ipa}',
].join(' ');

void main() {
  final lex = BritfoneLexicon.parse(_table);
  String? say(String word) => lex.pronunciations(word)?.first;

  test('parses entries and skips comments and bad lines', () {
    expect(lex.length, 17);
    expect(say('Cat'), 'k ˈæ t');
    expect(say('zzz'), isNull);
  });

  test('derives inflections', () {
    expect(say('cats'), 'k ˈæ t s');
    expect(say('dogs'), 'd ˈɒ ɡ z');
    expect(say('washes'), 'w ˈɒ ʃ ɪ z');
    expect(say('buses'), 'b ˈʌ s ɪ z');
    expect(say('flies'), 'f l ˈaɪ z');
    expect(say("cat's"), 'k ˈæ t s');
    expect(say('wanted'), 'w ˈɒ n t ɪ d');
    expect(say('washed'), 'w ˈɒ ʃ t');
    expect(say('played'), 'p l ˈeɪ d');
    expect(say('skipped'), 's k ˈɪ p t');
    expect(say('flied'), 'f l ˈaɪ d');
    expect(say('making'), 'm ˈeɪ k ɪ ŋ');
    expect(say('running'), 'ɹ ˈʌ n ɪ ŋ');
    expect(say('class'), isNull);
    expect(say('sing'), isNull);
  });

  test('derives contractions', () {
    expect(say("I'm"), 'ˈaɪ m');
    expect(say('I’ll'), 'ˈaɪ l');
    expect(say("that'll"), 'ð ˈæ t ə l');
    expect(say("cat'd"), 'k ˈæ t ə d');
    expect(say("they're"), 'ð ˈeə');
    expect(say("zz'm"), isNull);
  });

  test('lookup gives indexes, offsets and context forms', () {
    final words = lex.lookup('The apple is for the cat, for it. zzq');
    expect(words.map((w) => w.text), [
      'The', 'apple', 'is', 'for', 'the', 'cat', 'for', 'it', 'zzq', //
    ]);
    expect(words.map((w) => w.index), List.generate(9, (i) => i));
    expect(words.map((w) => w.offset), [0, 4, 10, 13, 17, 21, 26, 30, 34]);
    expect(ipa(words[0].phonemes), 'ð i'); // before a vowel sound
    expect(words[2].scorable, isFalse); // "is" is not in this table
    expect(ipa(words[3].phonemes), 'f ə'); // weak form
    expect(ipa(words[4].phonemes), 'ð ə');
    expect(ipa(words[6].phonemes), 'f ə');
    expect(ipa(words[7].phonemes), 'ˈɪ t'); // strong before a full stop
    expect(words[8].scorable, isFalse);
    expect(words[8].phonemes, isEmpty);
  });

  test(
    'weak forms are strong at the end of the text, pre-vowel only mid-clause',
    () {
      expect(ipa(lex.lookup('for').single.phonemes), 'f ˈɔː');
      expect(ipa(lex.lookup('to apple').first.phonemes), 't ʊ');
      expect(ipa(lex.lookup('the, apple').first.phonemes), 'ð ˈiː');
      expect(ipa(lex.lookup('the zzq').first.phonemes), 'ð ə');
    },
  );

  test('toPhonemes reads stress marks', () {
    expect(BritfoneLexicon.toPhonemes('ˌæ b ə d ˈiː n'), const [
      PhonemeSpec(ipa: 'æ', stress: 2),
      PhonemeSpec(ipa: 'b'),
      PhonemeSpec(ipa: 'ə'),
      PhonemeSpec(ipa: 'd'),
      PhonemeSpec(ipa: 'iː', stress: 1),
      PhonemeSpec(ipa: 'n'),
    ]);
  });
}
