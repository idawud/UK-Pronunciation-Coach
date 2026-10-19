import '../../core/models/models.dart';

/// The bundled British dictionary (assets/content/britfone.v1.tsv) and the rules that
/// turn text into expected phonemes.
///
/// Mirrors `tools/content/lexicon.py`, which builds the passages, so custom text and
/// library passages get the same pronunciations (checked by a test over every passage):
/// - Britfone words, with the preferred variant first (tools/content/variants.tsv);
/// - regular inflections (-s, 's, -ed, -ing) and contractions (I'm, they're, we'll)
///   derived from Britfone words;
/// - weak-form words (first variant unstressed, e.g. "for" /fə/) take their strong form
///   before clause punctuation or at the end of the text;
/// - "the" and "to" take their pre-vowel forms (/ði/, /tʊ/) before a vowel sound.
///
/// Words not covered get `scorable: false`. Never uses the network or eSpeak.
class BritfoneLexicon {
  BritfoneLexicon._(this._entries);

  /// Parses the tab-separated table: `word<TAB>pron|pron`, `#` comment lines.
  factory BritfoneLexicon.parse(String tsv) {
    final entries = <String, List<String>>{};
    for (final line in tsv.split('\n')) {
      if (line.isEmpty || line.startsWith('#')) continue;
      final tab = line.indexOf('\t');
      if (tab <= 0) continue;
      entries[line.substring(0, tab)] = line
          .substring(tab + 1)
          .trim()
          .split('|');
    }
    return BritfoneLexicon._(entries);
  }

  final Map<String, List<String>> _entries;

  /// Word tokens: letters with optional apostrophe parts ("don't", "Sarah's").
  static final RegExp wordPattern = RegExp(r"[A-Za-z]+(?:['’][A-Za-z]+)*");

  static final RegExp _clauseEnd = RegExp(r'^[^A-Za-z]*?[.,;:!?—–)"”]');

  static const Set<String> _vowels = {
    'ɪ',
    'ɛ',
    'æ',
    'ʌ',
    'ɒ',
    'ʊ',
    'ə',
    'i',
    'u',
    'iː',
    'ɑː',
    'ɔː',
    'uː',
    'ɜː', //
    'eɪ', 'aɪ', 'ɔɪ', 'əʊ', 'aʊ', 'ɪə', 'eə', 'ʊə',
  };
  static const Set<String> _sibilants = {'s', 'z', 'ʃ', 'ʒ', 'tʃ', 'dʒ'};
  static const Set<String> _voiceless = {'p', 't', 'k', 'f', 'θ'};
  static const Map<String, String> _preVowel = {'the': 'ð i', 'to': 't ʊ'};
  static const Map<String, String> _reForms = {
    "you're": 'j ˈɔː',
    "we're": 'w ˈɪə',
    "they're": 'ð ˈeə',
  };
  static const Map<String, (String, String)> _clitics = {
    "'m": ('m', 'ə m'),
    "'ll": ('l', 'ə l'),
    "'d": ('d', 'ə d'),
    "'ve": ('v', 'ə v'),
  };

  /// Number of dictionary entries.
  int get length => _entries.length;

  /// Lookup key: lower case, curly apostrophes straightened.
  static String key(String word) => word.replaceAll('’', "'").toLowerCase();

  /// All pronunciations of [word] (preferred first), derived ones included, or null.
  List<String>? pronunciations(String word) {
    final k = key(word);
    return _entries[k] ??
        switch (_derived(k)) {
          final d? => [d],
          _ => null,
        };
  }

  /// Words of [text] with expected phonemes and offsets, indexed from 0.
  List<WordSpec> lookup(String text) {
    final matches = wordPattern.allMatches(text).toList();
    return [for (var i = 0; i < matches.length; i++) _word(text, matches, i)];
  }

  WordSpec _word(String text, List<RegExpMatch> matches, int i) {
    final m = matches[i];
    final next = i + 1 < matches.length ? matches[i + 1] : null;
    final after = text.substring(m.end, next?.start ?? text.length);
    final pron = _inContext(m.group(0)!, after, next?.group(0));
    return WordSpec(
      text: m.group(0)!,
      index: i,
      offset: m.start,
      phonemes: pron == null ? const [] : toPhonemes(pron),
      scorable: pron != null,
    );
  }

  String? _inContext(String word, String after, String? nextWord) {
    final prons = pronunciations(word);
    if (prons == null) return null;
    final first = prons.first;
    final clauseEnd = nextWord == null || _clauseEnd.hasMatch(after);
    if (clauseEnd && !_isStressed(first)) {
      for (final p in prons) {
        if (_isStressed(p)) return p;
      }
    }
    final pre = _preVowel[key(word)];
    if (pre != null && !clauseEnd) {
      final nxt = pronunciations(nextWord);
      if (nxt != null && _vowels.contains(_strip(nxt.first.split(' ').first))) {
        return pre;
      }
    }
    return first;
  }

  String? _derived(String k) {
    final re = _reForms[k];
    if (re != null) return re;
    for (final MapEntry(key: clitic, value: forms) in _clitics.entries) {
      if (!k.endsWith(clitic)) continue;
      final base = _entries[k.substring(0, k.length - clitic.length)];
      if (base == null) break;
      final last = _strip(base.first.split(' ').last);
      return '${base.first} ${_vowels.contains(last) ? forms.$1 : forms.$2}';
    }
    for (final (bases, ending) in [
      (_sBases(k), _addS),
      (_edBases(k), _addEd),
      (_ingBases(k), _addIng),
    ]) {
      for (final b in bases) {
        final base = _entries[b];
        if (b.length > 1 && base != null) return ending(base.first);
      }
    }
    return null;
  }

  static List<String> _sBases(String k) {
    if (k.endsWith("'s")) return [k.substring(0, k.length - 2)];
    if (k.endsWith('ies')) return ['${k.substring(0, k.length - 3)}y'];
    if (k.endsWith('es')) {
      return [k.substring(0, k.length - 1), k.substring(0, k.length - 2)];
    }
    if (k.endsWith('s') && !k.endsWith('ss')) {
      return [k.substring(0, k.length - 1)];
    }
    return const [];
  }

  static List<String> _edBases(String k) {
    if (k.endsWith('ied')) return ['${k.substring(0, k.length - 3)}y'];
    if (!k.endsWith('ed')) return const [];
    final stem = k.substring(0, k.length - 2);
    return [
      stem,
      k.substring(0, k.length - 1),
      if (stem.length > 2 && stem[stem.length - 1] == stem[stem.length - 2])
        stem.substring(0, stem.length - 1),
    ];
  }

  static List<String> _ingBases(String k) {
    if (!k.endsWith('ing')) return const [];
    final stem = k.substring(0, k.length - 3);
    return [
      stem,
      '${stem}e',
      if (stem.length > 2 && stem[stem.length - 1] == stem[stem.length - 2])
        stem.substring(0, stem.length - 1),
    ];
  }

  static String _last(String pron) => _strip(pron.split(' ').last);

  static String _addS(String pron) {
    final last = _last(pron);
    if (_sibilants.contains(last)) return '$pron ɪ z';
    if (_voiceless.contains(last)) return '$pron s';
    return '$pron z';
  }

  static String _addEd(String pron) {
    final last = _last(pron);
    if (last == 't' || last == 'd') return '$pron ɪ d';
    if (_voiceless.contains(last) || const {'s', 'ʃ', 'tʃ'}.contains(last)) {
      return '$pron t';
    }
    return '$pron d';
  }

  static String _addIng(String pron) => '$pron ɪ ŋ';

  static String _strip(String token) => token.replaceAll(RegExp('[ˈˌ]'), '');

  static bool _isStressed(String pron) =>
      pron.split(' ').any((t) => t.startsWith('ˈ') || t.startsWith('ˌ'));

  /// `"k ˈæ t"` -> phonemes k, æ (primary stress), t.
  static List<PhonemeSpec> toPhonemes(String pron) => [
    for (final t in pron.split(' ').where((t) => t.isNotEmpty))
      PhonemeSpec(
        ipa: _strip(t),
        stress: t.startsWith('ˈ') ? 1 : (t.startsWith('ˌ') ? 2 : 0),
      ),
  ];
}
