import 'data/phoneme_map.dart';

/// Normalises an IPA phoneme: strips stress marks and tie bars, writes length as `ː`.
String normalizeIpa(String ipa) =>
    ipa.replaceAll(RegExp('[ˈˌ͜͡\']'), '').replaceAll(':', 'ː').trim();

/// The phoneme model's output symbols, read from `PhonemePosteriors.vocab`.
class ModelVocab {
  /// Indexes [symbols]; [blankIndex] is the CTC blank. Symbols written `<...>`
  /// (`<pad>`, `<s>`, `</s>`, `<unk>`) are special: never a phoneme or competitor.
  ModelVocab(this.symbols, this.blankIndex)
    : index = {for (var i = 0; i < symbols.length; i++) symbols[i]: i},
      isPhone = [
        for (var i = 0; i < symbols.length; i++)
          i != blankIndex && !_special.hasMatch(symbols[i]),
      ] {
    RangeError.checkValidIndex(blankIndex, symbols, 'blankIndex');
  }

  static final RegExp _special = RegExp(r'^<.*>$');

  /// Symbols by id.
  final List<String> symbols;

  /// Id of the CTC blank.
  final int blankIndex;

  /// Symbol -> id.
  final Map<String, int> index;

  /// True for ids that are phones (not blank or special).
  final List<bool> isPhone;

  /// Number of symbols.
  int get length => symbols.length;
}

/// One alignment unit: a set of model ids that all count as the expected sound.
class PhonemeUnit {
  /// Creates a unit with ids (non-empty, best first).
  const PhonemeUnit(this.ids);

  /// Accepted model ids, best first.
  final List<int> ids;

  /// True when [other] accepts exactly the same ids.
  bool sameAs(PhonemeUnit other) {
    if (ids.length != other.ids.length) return false;
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] != other.ids[i]) return false;
    }
    return true;
  }
}

/// Maps British IPA phonemes to alignment units over a [ModelVocab] using
/// [ssbePhonemeMap] plus [extraAccepted].
class PhonemeMapper {
  /// Creates a mapper for [vocab].
  PhonemeMapper(this.vocab, {this.extraAccepted = const {}});

  /// The model vocab.
  final ModelVocab vocab;

  /// Extra accepted symbols per normalised phoneme (from `ScoringConfig`).
  final Map<String, List<String>> extraAccepted;

  final Map<String, List<PhonemeUnit>> _cache = {};

  /// Units for [ipa] (in order). Empty when no symbol of the vocab fits.
  List<PhonemeUnit> unitsFor(String ipa) =>
      _cache.putIfAbsent(ipa, () => _resolve(normalizeIpa(ipa)));

  List<PhonemeUnit> _resolve(String key) {
    final realisations = [...?ssbePhonemeMap[key], ...?extraAccepted[key], key];
    final singles = <int>[];
    for (final r in realisations) {
      if (r.contains(' ')) continue;
      final id = vocab.index[r];
      if (id != null && vocab.isPhone[id] && !singles.contains(id)) {
        singles.add(id);
      }
    }
    if (singles.isNotEmpty) return [PhonemeUnit(singles)];
    for (final r in realisations) {
      if (!r.contains(' ')) continue;
      final ids = [for (final p in r.split(' ')) vocab.index[p]];
      if (ids.every((id) => id != null && vocab.isPhone[id])) {
        return [
          for (final id in ids) PhonemeUnit([id!]),
        ];
      }
    }
    if (key.endsWith('ː') && key.length > 1) {
      return _resolve(key.substring(0, key.length - 1));
    }
    return [
      for (final ch in key.runes.map(String.fromCharCode))
        if (vocab.index[ch] case final id? when vocab.isPhone[id])
          PhonemeUnit([id]),
    ];
  }
}
