// Shared golden-test helpers (W0-scaffold). Screen goldens should use these so every
// agent renders at the same sizes with the same fonts.
import 'package:flutter/material.dart';

/// Bundled fallback font with IPA glyphs (loaded in test/flutter_test_config.dart).
/// Roboto lacks ɜ, ɑ, ʊ, ː ..., and tests have no system font fallback.
const String testIpaFallbackFont = 'DejaVuSans';

/// Phone size used by screen goldens (logical pixels).
const Size goldenPhoneSize = Size(390, 844);

/// Tablet size used by screen goldens (logical pixels).
const Size goldenTabletSize = Size(820, 1180);

/// [theme] with the IPA fallback font applied to every text style, so IPA renders
/// in goldens. Use on the app theme: `withTestFonts(AppTheme.light())`.
ThemeData withTestFonts(ThemeData theme) {
  const fallback = [testIpaFallbackFont];
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: theme.primaryTextTheme.apply(
      fontFamilyFallback: fallback,
    ),
  );
}
