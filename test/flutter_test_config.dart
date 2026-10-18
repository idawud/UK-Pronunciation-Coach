// Runs before every test file under test/ (flutter_test convention).
//
// Loads the bundled Roboto and Material Icons fonts from test/fixtures/fonts/ so golden
// images render real text identically on every Linux machine, and configures alchemist:
// readable "platform" goldens only on Linux (CI and local Linux), obscured-text "ci"
// goldens everywhere.
import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadTestFonts();
  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(
        platforms: <HostPlatform>{HostPlatform.linux},
      ),
    ),
    run: testMain,
  );
}

/// Loads the fonts in test/fixtures/fonts/ under their family names.
Future<void> loadTestFonts() async {
  const families = {
    'Roboto': [
      'test/fixtures/fonts/Roboto-Regular.ttf',
      'test/fixtures/fonts/Roboto-Medium.ttf',
      'test/fixtures/fonts/Roboto-Bold.ttf',
    ],
    'MaterialIcons': ['test/fixtures/fonts/MaterialIcons-Regular.otf'],
    // IPA glyphs (ɜ, ɑ, ː, ʊ ...) that Roboto lacks; used as a fallback font.
    'DejaVuSans': ['test/fixtures/fonts/DejaVuSans.ttf'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final file = File(path);
      if (!file.existsSync()) continue;
      loader.addFont(
        Future.value(
          ByteData.sublistView(Uint8List.fromList(file.readAsBytesSync())),
        ),
      );
    }
    await loader.load();
  }
}
