import '../../../data/coach/coach_store.dart';

/// The last shadowing rhythm scores, kept under the Coach store key `shadow` as
/// `{"scores": [int, ...]}` (oldest first, at most [maxScores]).
///
/// Storage failures are swallowed: the score still shows on screen, it just is not
/// remembered.
class ShadowHistory {
  /// Creates the history over [_store] (the app's `coachStoreProvider`).
  ShadowHistory(this._store);

  /// Coach store key for this section.
  static const String key = 'shadow';

  /// How many scores are kept.
  static const int maxScores = 20;

  final CoachStore _store;

  /// The stored scores, oldest first. Empty when nothing is stored or it is unreadable.
  Future<List<int>> recent() async {
    try {
      final value = await _store.read(key);
      final raw = value?['scores'];
      if (raw is! List) return const [];
      return [
        for (final v in raw)
          if (v is num) v.round(),
      ];
    } on Object {
      return const [];
    }
  }

  /// Appends [score] (rounded), keeps the newest [maxScores], saves and returns the list.
  Future<List<int>> add(double score) async {
    final all = [...await recent(), score.round()];
    final kept = all.length > maxScores
        ? all.sublist(all.length - maxScores)
        : all;
    try {
      await _store.write(key, <String, Object?>{'scores': kept});
    } on Object {
      // Not remembered; the caller still shows the score.
    }
    return kept;
  }
}
