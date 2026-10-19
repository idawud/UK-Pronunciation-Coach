import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/data/data.dart';

import '../schemas/generated/schema.g.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('every schema version has a dumped schema and an upgrade step', () {
    const current = ProgressDatabase.currentSchemaVersion;
    for (var v = 1; v <= current; v++) {
      expect(
        File('test/data/schemas/drift_schema_v$v.json').existsSync(),
        isTrue,
        reason: 'run drift_dev schema dump for v$v',
      );
      if (v > 1) expect(ProgressDatabase.migrations, contains(v));
    }
    expect(GeneratedHelper.versions.last, current);
  });

  test('a fresh database matches the dumped schema', () async {
    final schema = await verifier.schemaAt(1);
    final db = ProgressDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });

  test('upgrades from every older version validate', () async {
    for (final from in GeneratedHelper.versions) {
      if (from == ProgressDatabase.currentSchemaVersion) continue;
      final schema = await verifier.schemaAt(from);
      final db = ProgressDatabase(schema.newConnection());
      await verifier.migrateAndValidate(
        db,
        ProgressDatabase.currentSchemaVersion,
      );
      await db.close();
    }
  });

  test('a database from a newer app version is refused', () async {
    final raw = NativeDatabase.memory(
      setup: (db) => db.execute('PRAGMA user_version = 99'),
    );
    final db = ProgressDatabase(raw);
    await expectLater(db.customSelect('SELECT 1').get(), throwsA(anything));
    await db.close();
  });

  test('data survives closing and reopening a database file', () async {
    final dir = await Directory.systemTemp.createTemp('c2_migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/sub/progress.sqlite');
    final repo = await DriftProgressRepository.open(file: file);
    await repo.saveAttempt(cannedRiverAttempt);
    await repo.close();

    final reopened = await DriftProgressRepository.open(file: file);
    expect(await reopened.attempt(cannedRiverAttempt.id), cannedRiverAttempt);
    final version = await reopened.database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, ProgressDatabase.currentSchemaVersion);
    await reopened.close();
  });
}
