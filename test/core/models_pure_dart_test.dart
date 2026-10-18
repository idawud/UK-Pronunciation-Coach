// The shared models, contracts and fakes must stay pure Dart: A3's scoring code and
// I2's desktop eval harness import them.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final path in [
    'lib/core/models',
    'lib/core/contracts',
    'lib/core/fakes',
  ]) {
    test('$path has no Flutter imports', () {
      final offenders = [
        for (final f in Directory(path).listSync().whereType<File>())
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
}
