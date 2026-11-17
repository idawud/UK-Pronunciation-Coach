import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/coach/coach_store.dart';
import 'describe_content.dart';

/// Store key for the circumlocution progress: `{doneIds: [...], lastDay: 'yyyy-mm-dd'}`.
const String describeCircKey = 'circ';

/// Store key for the phrase counts: `{counts: {id: n}}`.
const String describeChunksKey = 'chunks';

/// Seconds allowed for one prompt when the optional timer is used.
const int describeTimerSeconds = 30;

/// Starts a periodic timer, like `Timer.periodic`. Injected so tests can drive the
/// countdown with fake_async or replace it entirely.
typedef CountdownTicker = Timer Function(
  Duration interval,
  void Function(Timer timer) tick,
);

/// Ticker used by the countdown. Tests override it.
final describeTimerProvider = Provider<CountdownTicker>(
  (ref) => Timer.periodic,
);

/// Progress through the prompts. [doneIds] is the current round; it is emptied when a
/// round completes, so the picker starts again from every prompt.
class CircState {
  /// Creates the state.
  const CircState({this.doneIds = const <String>{}, this.lastDay});

  /// Prompt ids completed in the current round.
  final Set<String> doneIds;

  /// Local calendar day of the last completed prompt, as `yyyy-mm-dd`.
  final String? lastDay;
}

/// Picks the next prompt: a random prompt whose id is not in [doneIds], avoiding
/// [exclude] when another choice exists. When every prompt is done the whole list is
/// eligible again (the round has reset). Returns null only when [prompts] is empty.
CircumlocutionPrompt? pickPrompt({
  required List<CircumlocutionPrompt> prompts,
  required Set<String> doneIds,
  String? exclude,
  Random? random,
}) {
  if (prompts.isEmpty) return null;
  var pool = prompts.where((p) => !doneIds.contains(p.id)).toList();
  if (pool.isEmpty) pool = List.of(prompts);
  final withoutCurrent = pool.where((p) => p.id != exclude).toList();
  if (withoutCurrent.isNotEmpty) pool = withoutCurrent;
  return pool[(random ?? Random()).nextInt(pool.length)];
}

/// True when every prompt in [prompts] is in [doneIds].
bool roundComplete({
  required List<CircumlocutionPrompt> prompts,
  required Set<String> doneIds,
}) => prompts.every((p) => doneIds.contains(p.id));

/// Reads and writes the Describe progress through [CoachStore]. Dates come from the
/// injected clock, so tests can move across midnight.
class DescribeRepository {
  /// Creates the repository over [_store], reading today from [_clock].
  DescribeRepository(this._store, this._clock);

  final CoachStore _store;
  final DateTime Function() _clock;

  /// Loads the round progress. Missing or malformed data reads as an empty round.
  Future<CircState> loadCirc() async {
    final raw = await _store.read(describeCircKey);
    final ids = raw?['doneIds'];
    final day = raw?['lastDay'];
    return CircState(
      doneIds: ids is List ? ids.whereType<String>().toSet() : <String>{},
      lastDay: day is String ? day : null,
    );
  }

  /// Marks [id] done for today and returns the new state. When that completes the
  /// round, the done list is cleared and stored empty so the next round starts fresh.
  Future<CircState> markDone(String id) async {
    final current = await loadCirc();
    final done = {...current.doneIds, id};
    final ids = roundComplete(prompts: circumlocutionPrompts, doneIds: done)
        ? <String>{}
        : done;
    final day = _dayKey(_clock());
    final next = CircState(doneIds: ids, lastDay: day);
    await _store.write(describeCircKey, {
      'doneIds': ids.toList()..sort(),
      'lastDay': day,
    });
    return next;
  }

  /// Phrase counts by id. Missing or malformed data reads as no counts.
  Future<Map<String, int>> loadCounts() async {
    final raw = await _store.read(describeChunksKey);
    final counts = raw?['counts'];
    if (counts is! Map) return <String, int>{};
    return {
      for (final e in counts.entries)
        if (e.key is String && e.value is int && (e.value as int) > 0)
          e.key as String: e.value as int,
    };
  }

  /// Adds one practice to [id] and returns the new counts.
  Future<Map<String, int>> practise(String id) async {
    final counts = await loadCounts();
    counts[id] = (counts[id] ?? 0) + 1;
    await _store.write(describeChunksKey, {'counts': counts});
    return counts;
  }

  static String _dayKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}

/// The Describe repository, bound to the Coach store and the app clock.
final describeRepositoryProvider = Provider<DescribeRepository>(
  (ref) => DescribeRepository(
    ref.watch(coachStoreProvider),
    ref.watch(clockProvider),
  ),
);

/// Saved round progress. The screen invalidates it on remount, not on every change.
final describeCircProvider = FutureProvider.autoDispose<CircState>(
  (ref) => ref.watch(describeRepositoryProvider).loadCirc(),
);

/// Saved phrase practice counts.
final chunkCountsProvider = FutureProvider.autoDispose<Map<String, int>>(
  (ref) => ref.watch(describeRepositoryProvider).loadCounts(),
);

/// The [count] most-practised phrases with a count above zero, most first. Ties keep
/// the order of [phraseChunks].
List<PhraseChunk> mostPractised(
  Map<String, int> counts, {
  int count = 3,
  List<PhraseChunk> chunks = phraseChunks,
}) {
  final practised = chunks.where((c) => (counts[c.id] ?? 0) > 0).toList()
    ..sort((a, b) => counts[b.id]!.compareTo(counts[a.id]!));
  return practised.take(count).toList();
}
