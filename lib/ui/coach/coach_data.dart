import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/contracts/tips.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';

/// How many weakest sounds the Coach tab turns into guided exercises.
const int coachGuidedCount = 3;

/// How many minimal pairs one guided exercise shows.
const int coachPairsPerExercise = 3;

/// One guided exercise: a weak sound, its tip and minimal pairs that drill it.
class GuidedExercise {
  /// Creates a guided exercise.
  const GuidedExercise({
    required this.stat,
    this.tip,
    this.pairs = const <MinimalPair>[],
  });

  /// The sound (accuracy and attempts).
  final SoundStat stat;

  /// First available tip for this sound, or null.
  final String? tip;

  /// Minimal pairs whose contrast includes [stat] ipa, at most
  /// [coachPairsPerExercise].
  final List<MinimalPair> pairs;
}

/// Builds the guided exercises: the [count] weakest sounds with at least one scored
/// attempt, weakest (lowest accuracy) first. Each gets up to
/// [coachPairsPerExercise] pairs whose contrast (e.g. `ɪ-iː`) contains its ipa, and
/// the first non-null `tips.tipFor(ipa, counterpart)` over those pairs as its tip.
///
/// Pure: no I/O, so it is unit tested directly. Empty [stats] gives an empty list.
List<GuidedExercise> buildGuidedExercises({
  required List<SoundStat> stats,
  required List<MinimalPair> pairs,
  required Tips tips,
  int count = coachGuidedCount,
}) {
  final candidates = stats.where((s) => s.attempts > 0).toList()
    ..sort((a, b) {
      final byAccuracy = a.accuracy.compareTo(b.accuracy);
      return byAccuracy != 0 ? byAccuracy : a.ipa.compareTo(b.ipa);
    });
  return [
    for (final stat in candidates.take(count)) _guidedFor(stat, pairs, tips),
  ];
}

GuidedExercise _guidedFor(SoundStat stat, List<MinimalPair> pairs, Tips tips) {
  final matching = <MinimalPair>[];
  String? tip;
  for (final pair in pairs) {
    if (matching.length == coachPairsPerExercise) break;
    final sides = pair.contrast.split('-');
    if (!sides.contains(stat.ipa)) continue;
    matching.add(pair);
    final counterpart = sides.firstWhere(
      (side) => side != stat.ipa,
      orElse: () => '',
    );
    tip ??= tips.tipFor(stat.ipa, counterpart);
  }
  return GuidedExercise(stat: stat, tip: tip, pairs: matching);
}

/// Coach data: guided exercises for the weakest sounds. Refreshes after every progress
/// write, mirroring `practiseDataProvider`.
final coachDataProvider = FutureProvider.autoDispose<List<GuidedExercise>>((
  ref,
) async {
  ref.watch(progressChangesProvider);
  final stats = await ref.watch(progressRepositoryProvider).soundStats();
  final pairs = await ref.watch(contentRepositoryProvider).minimalPairs();
  return buildGuidedExercises(
    stats: stats,
    pairs: pairs,
    tips: ref.watch(tipsProvider),
  );
});
