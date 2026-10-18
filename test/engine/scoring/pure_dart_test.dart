// Seeded by W0-scaffold for A3-scoring: lib/engine/scoring must stay pure Dart so its
// tests run fast and it can run in an isolate or a desktop CLI (I2's eval harness).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/engine/scoring has no Flutter imports', () {
    final dir = Directory('lib/engine/scoring');
    if (!dir.existsSync()) return;
    final offenders = [
      for (final f in dir.listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') &&
            RegExp(
              r'''^\s*(import|export)\s+['"](package:flutter/|dart:ui)''',
              multiLine: true,
            ).hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
