// Proves the golden setup (alchemist + bundled Roboto / Material Icons from
// test/fixtures/fonts/, configured in test/flutter_test_config.dart) without depending
// on any screen. Screen goldens live next to this file, one per screen, owned by the
// screen's agent: light + dark, phone (390x844) + tablet (820x1180).
//
// Update images on Linux only:  flutter test --update-goldens --tags golden
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';

import '../../helpers/golden.dart';

class _Sample extends StatelessWidget {
  const _Sample();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('A walk by the river', style: t.titleLarge),
          const SizedBox(height: 8),
          Text(
            'On Thursday we walked by the river. θ ɜː ɑː ð',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic),
              SizedBox(width: 8),
              Icon(Icons.volume_up),
              SizedBox(width: 8),
              Icon(Icons.error_outline),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: () {}, child: const Text('Fix 3 red words')),
        ],
      ),
    );
  }
}

void main() {
  goldenTest(
    'golden setup renders bundled fonts in light and dark',
    fileName: 'golden_setup',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'light',
          child: Theme(
            data: withTestFonts(
              ThemeData(useMaterial3: true, brightness: Brightness.light),
            ),
            child: const Material(child: _Sample()),
          ),
        ),
        GoldenTestScenario(
          name: 'dark',
          child: Theme(
            data: withTestFonts(
              ThemeData(useMaterial3: true, brightness: Brightness.dark),
            ),
            child: const Material(child: _Sample()),
          ),
        ),
      ],
    ),
  );
}
