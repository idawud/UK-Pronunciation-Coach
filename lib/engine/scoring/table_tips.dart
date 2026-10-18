import '../../core/contracts/tips.dart';
import 'data/phoneme_map.dart';
import 'data/tips_table.dart';
import 'phoneme_mapper.dart';

/// [Tips] backed by the tables in `data/tips_table.dart`.
class TableTips implements Tips {
  /// Creates the tips.
  const TableTips();

  /// Spellings folded together before lookup (Britfone, model and legacy forms).
  static const Map<String, String> _canonical = {
    'e': 'ɛ',
    'ɛə': 'eə',
    'ɛː': 'eə',
    'r': 'ɹ',
    'g': 'ɡ',
    'ʧ': 'tʃ',
    'ʤ': 'dʒ',
    'ɐ': 'ə',
    'ᵻ': 'ɪ',
    'ɔ': 'ɔː',
    'ɑ': 'ɑː',
    'ɜ': 'ɜː',
  };

  static String _norm(String ipa) {
    final n = normalizeIpa(ipa);
    return _canonical[n] ?? n;
  }

  /// Number of advice entries (substitutions + dropped sounds + general + r).
  static int get entryCount =>
      substitutionTips.values.fold(0, (s, m) => s + m.length) +
      droppedTips.length +
      generalTips.length +
      1;

  @override
  String? tipFor(String expected, String? heard) {
    if (heard == null) return null;
    final e = _norm(expected);
    final h = _norm(heard);
    if (h == e) return null;
    if (e.isEmpty) return null;
    if (h.isEmpty) {
      return droppedTips[e] ??
          "Don't leave out the /$e/ sound; say it clearly.";
    }
    final exact = substitutionTips[e]?[h];
    if (exact != null) return exact;
    if (ssbeVowels.contains(e) && _soundsR(e, h)) return rhoticTip;
    return generalTips[e];
  }

  static bool _soundsR(String expected, String heard) {
    if (rhoticSymbols.contains(heard) && heard != 'ɹ' && heard != 'r') {
      return true;
    }
    if (heard.length > expected.length && heard.startsWith(expected)) {
      final rest = heard.substring(expected.length);
      return rest == 'ɹ' || rest == 'r';
    }
    return false;
  }
}
