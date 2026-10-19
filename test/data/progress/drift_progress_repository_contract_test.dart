import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/data/data.dart';

import '../../contracts/progress_repository_contract.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  group('DriftProgressRepository (in-memory)', () {
    runProgressRepositoryContract(
      (clock) async => DriftProgressRepository.inMemory(clock: clock),
    );
  });
}
