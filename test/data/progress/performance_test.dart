import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/data/data.dart';

/// Performance target (CLAUDE.md): 1,000 attempts load in < 200 ms.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('1,000 attempts of 60 words load in under 200 ms', () async {
    final repo = DriftProgressRepository.inMemory(
      clock: () => DateTime(2026, 10, 18),
    );
    addTearDown(repo.close);

    // A 60-word attempt (spec: typical passage), built from the canned river words.
    final base = cannedRiverAttempt.words;
    final words = [
      for (var i = 0; i < 60; i++) base[i % base.length].copyWith(index: i),
    ];
    final template = cannedRiverAttempt.copyWith(words: words);
    final start = DateTime(2024, 1, 1, 8);
    await repo.database.transaction(() async {
      for (var i = 0; i < 1000; i++) {
        await repo.saveAttempt(
          template.copyWith(
            id: 'perf-$i',
            at: start.add(Duration(hours: i)),
          ),
        );
      }
    });

    // Best of 5 runs: the first warms the JIT and statement cache, and the minimum
    // filters out scheduling noise on shared CI machines.
    var best = const Duration(days: 1);
    late List<AttemptResult> all;
    for (var run = 0; run < 5; run++) {
      final sw = Stopwatch()..start();
      all = await repo.attempts();
      sw.stop();
      if (sw.elapsed < best) best = sw.elapsed;
    }

    expect(all, hasLength(1000));
    expect(all.first.words, hasLength(60));
    expect(all.first.words.first.phonemes, isNotEmpty);
    // ignore: avoid_print
    print(
      'Loaded 1,000 attempts (60,000 words) in ${best.inMilliseconds} ms (best of 5)',
    );
    expect(best, lessThan(const Duration(milliseconds: 200)));
  });
}
