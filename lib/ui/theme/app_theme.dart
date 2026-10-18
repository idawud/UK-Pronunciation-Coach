import 'package:flutter/material.dart';

import 'score_colors.dart';

/// App themes (placeholder from W0; U1 owns and replaces the look, keeping
/// `AppTheme.light()` / `AppTheme.dark()` and the [ScoreColors] extension).
abstract final class AppTheme {
  static const Color _seed = Color(0xFF1F4E79);

  /// Light theme.
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    extensions: const [ScoreColors.light],
  );

  /// Dark theme.
  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
    extensions: const [ScoreColors.dark],
  );
}
