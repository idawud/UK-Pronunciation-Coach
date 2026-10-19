// Settings screen goldens (U4-progress): phone and tablet, light and dark, plus a
// phone with the full model downloading and no British voice installed.
// Update on Linux: flutter test --update-goldens --tags golden
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/settings/settings_providers.dart';
import 'package:uk_pronunciation_coach/ui/settings/settings_screen.dart';

import '../../helpers/golden.dart';
import '../progress/u4_harness.dart';

Widget _scenario(
  Size size,
  Brightness brightness, {
  bool downloadingNoVoice = false,
}) {
  final repo = FakeProgressRepository(clock: testClock);
  return SizedBox.fromSize(
    size: size,
    child: testApp(
      const SettingsScreen(),
      overrides: [
        ...overridesFor(
          repo: repo,
          voice: FakeVoiceService(britishVoice: !downloadingNoVoice),
        ),
        if (downloadingNoVoice)
          modelDownloadProvider.overrideWithValue(
            const AsyncData(
              ModelDownloadProgress(
                state: DownloadState.downloading,
                receivedBytes: 134 * 1024 * 1024,
                totalBytes: 320 * 1024 * 1024,
              ),
            ),
          ),
      ],
      brightness: brightness,
      wrapTheme: withTestFonts,
    ),
  );
}

void main() {
  goldenTest(
    'Settings on a phone',
    fileName: 'settings_phone',
    builder: () => GoldenTestGroup(
      columns: 3,
      children: [
        GoldenTestScenario(
          name: 'light',
          child: _scenario(goldenPhoneSize, Brightness.light),
        ),
        GoldenTestScenario(
          name: 'dark',
          child: _scenario(goldenPhoneSize, Brightness.dark),
        ),
        GoldenTestScenario(
          name: 'downloading, no British voice',
          child: _scenario(
            const Size(390, 1800),
            Brightness.light,
            downloadingNoVoice: true,
          ),
        ),
      ],
    ),
  );

  goldenTest(
    'Settings on a tablet',
    fileName: 'settings_tablet',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        GoldenTestScenario(
          name: 'light',
          child: _scenario(goldenTabletSize, Brightness.light),
        ),
        GoldenTestScenario(
          name: 'dark',
          child: _scenario(goldenTabletSize, Brightness.dark),
        ),
      ],
    ),
  );
}
