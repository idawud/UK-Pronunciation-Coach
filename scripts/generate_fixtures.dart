// Writes the canned JSON fixtures in test/fixtures/{passages,posteriors,results}/ from
// lib/core/fakes/sample_data.dart, so tests in any language can load them.
//
//   dart run scripts/generate_fixtures.dart
//
// test/fixtures/fixtures_test.dart fails if these files drift from the sample data.
import 'dart:convert';
import 'dart:io';

import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';

void main() {
  final files = <String, Object>{
    'passages/sample_passages.json': [
      for (final p in samplePassages) p.toJson(),
    ],
    'posteriors/river_canned.json': riverPosteriors.toJson(),
    'posteriors/tea_perfect.json': syntheticPosteriors(teaPassage).toJson(),
    'results/river_canned_attempt.json': cannedRiverAttempt.toJson(),
  };
  for (final MapEntry(key: path, value: json) in files.entries) {
    final file = File('test/fixtures/$path')
      ..parent.createSync(recursive: true);
    file.writeAsStringSync('${jsonEncode(json)}\n');
    stdout.writeln('wrote ${file.path} (${file.lengthSync()} bytes)');
  }
}
