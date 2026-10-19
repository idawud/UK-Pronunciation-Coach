import 'package:flutter/material.dart';

import 'score_colors.dart';
import 'typography.dart';

/// App themes: Material 3, light and dark, from one navy seed, with large readable
/// type, the bundled IPA font as a fallback for every style, and [ScoreColors].
/// `AppTheme.light()` / `AppTheme.dark()` and the [ScoreColors] extension are the API.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF1F4E79);

  /// Light theme.
  static ThemeData light() => _build(Brightness.light, ScoreColors.light);

  /// Dark theme.
  static ThemeData dark() => _build(Brightness.dark, ScoreColors.dark);

  static ThemeData _build(Brightness brightness, ScoreColors scores) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );
    const fallback = [AppTypography.ipaFontFamily];
    final text = base.textTheme
        .copyWith(
          bodyLarge: base.textTheme.bodyLarge!.copyWith(fontSize: 17),
          bodyMedium: base.textTheme.bodyMedium!.copyWith(fontSize: 15),
        )
        .apply(fontFamilyFallback: fallback);
    return base.copyWith(
      textTheme: text,
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamilyFallback: fallback,
      ),
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: text.titleMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        linearMinHeight: 8,
      ),
      extensions: [scores],
    );
  }
}
