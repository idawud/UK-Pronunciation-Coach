import 'package:flutter/foundation.dart';

/// Maps the contract's speaking rate (1.0 normal, 0.6 slow, valid 0.1-2.0, a
/// multiplier of natural speed) to the value passed to flutter_tts `setSpeechRate`.
///
/// flutter_tts scales differ by platform:
///
/// * **Android** (`TextToSpeech.setSpeechRate`, 1.0 = normal, linear): the plug-in
///   multiplies the value by 2 before passing it on, so flutter_tts 0.5 is normal.
///   We send `rate / 2`, so the native rate equals the contract rate exactly
///   (1.0 -> 0.5 -> native 1.0; 0.6 -> 0.3 -> native 0.6).
/// * **iOS / macOS** (`AVSpeechUtterance.rate`, passed through unchanged): range
///   0.0-1.0, default (normal) 0.5, and the scale is not linear in speed; values
///   below the default slow speech down more steeply than values above speed it up.
///   Normal 1.0 -> 0.5. Below 1.0 we use a gentler slope ([iosSlowSlope]) so slow
///   0.6 -> 0.35, which sounds about 0.6x; above 1.0 the scale is linear to 1.0 at
///   2.0. Re-check 0.35 by ear on a device (see docs/handoff/C4-voice.md).
/// * Other platforms (web, desktop: not shipped) use the Android mapping.
abstract final class TtsRateMapping {
  /// AVSpeechUtterance rate for each contract unit below normal.
  static const double iosSlowSlope = 0.375;

  /// flutter_tts value for the contract [rate] on [platform], clamped to 0-1.
  static double toEngine(double rate, TargetPlatform platform) {
    final double value;
    switch (platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        value = rate <= 1.0
            ? 0.5 - (1.0 - rate) * iosSlowSlope
            : 0.5 + (rate - 1.0) * 0.5;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        value = rate / 2;
    }
    return value.clamp(0.0, 1.0);
  }
}
