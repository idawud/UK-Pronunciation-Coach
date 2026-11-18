import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/coach/coach_store.dart';

/// Store key for the IPA lessons: `{learned: [symbols]}`.
const String ipaStoreKey = 'ipa';

/// Reads and writes the learned sounds through the Coach store. Malformed data reads
/// as nothing learned.
class IpaRepository {
  /// Creates the repository over [_store].
  IpaRepository(this._store);

  final CoachStore _store;

  /// Symbols marked learned.
  Future<Set<String>> loadLearned() async {
    final raw = await _store.read(ipaStoreKey);
    final list = raw?['learned'];
    if (list is! List) return <String>{};
    return {
      for (final v in list)
        if (v is String) v,
    };
  }

  /// Marks [symbol] learned or not learned and returns the new set.
  Future<Set<String>> setLearned(String symbol, bool learned) async {
    final current = await loadLearned();
    if (learned) {
      current.add(symbol);
    } else {
      current.remove(symbol);
    }
    await _store.write(ipaStoreKey, {'learned': current.toList()..sort()});
    return current;
  }
}

/// The IPA repository, bound to the Coach store.
final ipaRepositoryProvider = Provider<IpaRepository>(
  (ref) => IpaRepository(ref.watch(coachStoreProvider)),
);

/// Symbols marked learned. Refreshed with `ref.invalidate` after each write.
final ipaLearnedProvider = FutureProvider.autoDispose<Set<String>>(
  (ref) => ref.watch(ipaRepositoryProvider).loadLearned(),
);

/// Random source for the Quick check. Tests override it with a seeded `Random`.
final ipaRandomProvider = Provider<Random>((ref) => Random());
