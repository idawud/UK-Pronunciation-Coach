#!/usr/bin/env bash
# Dumps the current drift schema of the progress database and regenerates the test
# helpers used by test/data/progress/migration_test.dart. Run after every schema change
# (after bumping ProgressDatabase.currentSchemaVersion and running build_runner).
# Generated helpers are renamed to *.g.dart so format/analyze skip them like other
# generated code.
set -euo pipefail
cd "$(dirname "$0")/../../.."
dart run drift_dev schema dump lib/data/progress/progress_database.dart test/data/schemas/
rm -rf test/data/schemas/generated
dart run drift_dev schema generate test/data/schemas/ test/data/schemas/generated/
cd test/data/schemas/generated
for f in schema*.dart; do
  [[ "$f" == *.g.dart ]] && continue
  sed -E "s/'(schema_v[0-9]+)\.dart'/'\1.g.dart'/" "$f" > "${f%.dart}.g.dart"
  rm "$f"
done
