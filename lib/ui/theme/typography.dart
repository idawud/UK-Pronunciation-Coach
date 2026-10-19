import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Shared text styles: passage text (18-22 sp, adjustable) and IPA.
abstract final class AppTypography {
  /// Bundled IPA-capable font family (Noto Sans, SIL OFL 1.1; see pubspec.yaml).
  static const String ipaFontFamily = 'NotoSansIPA';

  /// Smallest passage text size (sp).
  static const double passageMinSize = 18;

  /// Default passage text size (sp), `UserProfile.textScale == 1.0`.
  static const double passageDefaultSize = 20;

  /// Largest passage text size (sp).
  static const double passageMaxSize = 22;

  /// Passage text size for a profile `textScale` (1.0 = 20 sp), clamped to 18-22.
  static double passageSizeForScale(double textScale) =>
      (passageDefaultSize * textScale).clamp(passageMinSize, passageMaxSize);

  /// The profile `textScale` to store for a passage text [size] (clamped to 18-22).
  static double textScaleForSize(double size) =>
      size.clamp(passageMinSize, passageMaxSize) / passageDefaultSize;

  /// Passage reading style at [size] sp (use `ref.watch(passageTextSizeProvider)`).
  static TextStyle passage(BuildContext context, {double? size}) =>
      Theme.of(context).textTheme.bodyLarge!.copyWith(
        fontSize: size ?? passageDefaultSize,
        height: 1.6,
        letterSpacing: 0.1,
      );

  /// Style for IPA transcriptions such as /θ ˈɜː z d eɪ/. Uses the bundled font so
  /// every symbol renders on every device. [size] defaults to bodyLarge's size.
  static TextStyle ipa(BuildContext context, {double? size}) {
    final base = Theme.of(context).textTheme.bodyLarge!;
    return base.copyWith(
      fontFamily: ipaFontFamily,
      fontFamilyFallback: [...?base.fontFamilyFallback, ipaFontFamily],
      fontSize: size ?? base.fontSize,
      letterSpacing: 0.5,
    );
  }

  /// [phonemes] as a slash-wrapped IPA string, e.g. `/θ ɜː z d eɪ/`.
  static String slashes(Iterable<String> phonemes) => '/${phonemes.join(' ')}/';
}

/// Passage text size in sp (18-22), from `UserProfile.textScale`. Settings (U4) changes
/// it by saving the profile with `AppTypography.textScaleForSize(size)`.
final passageTextSizeProvider = Provider<double>((ref) {
  final profile = ref.watch(userProfileProvider).value;
  return AppTypography.passageSizeForScale(profile?.textScale ?? 1.0);
});
