import 'package:flutter/material.dart';

import '../../core/models/enums.dart';

/// Score colour tokens (U1 owns the values; the class name, fields and [of] are what
/// U2/U3/U4 code against). Read with `ScoreColors.of(context)`, never hard-code colours.
@immutable
class ScoreColors extends ThemeExtension<ScoreColors> {
  /// Creates the tokens.
  const ScoreColors({
    required this.good,
    required this.close,
    required this.fix,
    required this.notScored,
  });

  /// Score >= 80.
  final Color good;

  /// Score 60-79.
  final Color close;

  /// Score < 60 and missed words.
  final Color fix;

  /// Words that are not scored.
  final Color notScored;

  /// Placeholder light values (U1 replaces with WCAG AA checked colours).
  static const light = ScoreColors(
    good: Color(0xFF1B7F3B),
    close: Color(0xFF9A6100),
    fix: Color(0xFFB3261E),
    notScored: Color(0xFF6B6B6B),
  );

  /// Placeholder dark values.
  static const dark = ScoreColors(
    good: Color(0xFF7BD88F),
    close: Color(0xFFFFC266),
    fix: Color(0xFFFF8A80),
    notScored: Color(0xFFB0B0B0),
  );

  /// The tokens of the current theme (light values if the theme has none).
  static ScoreColors of(BuildContext context) =>
      Theme.of(context).extension<ScoreColors>() ?? light;

  /// Colour for a word [status].
  Color forStatus(WordStatus status) => switch (status) {
    WordStatus.good => good,
    WordStatus.close => close,
    WordStatus.fix || WordStatus.missed => fix,
    WordStatus.notScored => notScored,
  };

  @override
  ScoreColors copyWith({
    Color? good,
    Color? close,
    Color? fix,
    Color? notScored,
  }) => ScoreColors(
    good: good ?? this.good,
    close: close ?? this.close,
    fix: fix ?? this.fix,
    notScored: notScored ?? this.notScored,
  );

  @override
  ScoreColors lerp(ScoreColors? other, double t) {
    if (other == null) return this;
    return ScoreColors(
      good: Color.lerp(good, other.good, t)!,
      close: Color.lerp(close, other.close, t)!,
      fix: Color.lerp(fix, other.fix, t)!,
      notScored: Color.lerp(notScored, other.notScored, t)!,
    );
  }
}
