// U1-home golden helpers: one screen scenario at a fixed size and theme, with
// seeded fakes.
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uk_pronunciation_coach/ui/theme/app_theme.dart';

import '../../helpers/golden.dart';
import '../shell/harness.dart';

/// A [screen] scenario named [name] at [size] in the light or [dark] theme.
GoldenTestScenario screenScenario(
  String name,
  Seeded seeded,
  Widget screen, {
  Size size = goldenPhoneSize,
  bool dark = false,
}) => GoldenTestScenario(
  name: name,
  constraints: BoxConstraints.tight(size),
  child: ProviderScope(
    overrides: seeded.overrides,
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: Theme(
        data: withTestFonts(dark ? AppTheme.dark() : AppTheme.light()),
        child: screen,
      ),
    ),
  ),
);
