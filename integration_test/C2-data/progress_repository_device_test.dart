// On-device SQLite tests for C2-data: the shared ProgressRepository contract against a
// real database file in the app's support directory, persistence across reopen, and
// the 1,000-attempt load target on the device.
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/data/data.dart';

import '../../test/contracts/progress_repository_contract.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  var n = 0;
  Future<File> freshFile() async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/c2_device/${n++}/progress.sqlite');
    if (await f.parent.exists()) await f.parent.delete(recursive: true);
    return f;
  }

  group('DriftProgressRepository (device file)', () {
    runProgressRepositoryContract(
      (clock) async =>
          DriftProgressRepository.open(file: await freshFile(), clock: clock),
    );
  });

  testWidgets('default location opens and persists across reopen', (_) async {
    final repo = await DriftProgressRepository.open();
    await repo.deleteAll();
    await repo.saveAttempt(cannedRiverAttempt);
    await repo.close();
    final again = await DriftProgressRepository.open();
    expect(await again.attempt(cannedRiverAttempt.id), cannedRiverAttempt);
    await again.deleteAll();
    await again.close();
  });

  testWidgets('1,000 attempts load in under 200 ms', (_) async {
    final repo = await DriftProgressRepository.open(file: await freshFile());
    final base = cannedRiverAttempt.words;
    final words = [
      for (var i = 0; i < 60; i++) base[i % base.length].copyWith(index: i),
    ];
    final template = cannedRiverAttempt.copyWith(words: words);
    await repo.database.transaction(() async {
      for (var i = 0; i < 1000; i++) {
        await repo.saveAttempt(
          template.copyWith(
            id: 'perf-$i',
            at: DateTime(2024).add(Duration(hours: i)),
          ),
        );
      }
    });
    await repo.attempts(limit: 5);
    final sw = Stopwatch()..start();
    final all = await repo.attempts();
    sw.stop();
    expect(all, hasLength(1000));
    expect(sw.elapsed, lessThan(const Duration(milliseconds: 200)));
    await repo.close();
  });
}
