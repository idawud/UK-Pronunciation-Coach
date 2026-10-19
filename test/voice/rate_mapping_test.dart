import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/voice_service.dart';
import 'package:uk_pronunciation_coach/voice/rate_mapping.dart';

void main() {
  double map(double r, TargetPlatform p) => TtsRateMapping.toEngine(r, p);

  group('Android (flutter_tts doubles the value; native 1.0 = normal)', () {
    const p = TargetPlatform.android;
    test('normal 1.0 -> 0.5 (native 1.0)', () {
      expect(map(VoiceService.normalRate, p), 0.5);
      expect(map(VoiceService.normalRate, p) * 2, VoiceService.normalRate);
    });
    test('slow 0.6 -> 0.3 (native 0.6)', () {
      expect(map(VoiceService.slowRate, p), closeTo(0.3, 1e-9));
    });
    test('range ends', () {
      expect(map(0.1, p), closeTo(0.05, 1e-9));
      expect(map(2.0, p), 1.0);
    });
  });

  for (final p in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    group('$p (AVSpeechUtterance.rate, default 0.5)', () {
      test('normal 1.0 -> 0.5 (AVSpeechUtteranceDefaultSpeechRate)', () {
        expect(map(1.0, p), 0.5);
      });
      test('slow 0.6 -> 0.35', () {
        expect(map(0.6, p), closeTo(0.35, 1e-9));
      });
      test('fast and range ends stay within 0-1', () {
        expect(map(1.5, p), closeTo(0.75, 1e-9));
        expect(map(2.0, p), 1.0);
        expect(map(0.1, p), closeTo(0.1625, 1e-9));
      });
    });
  }

  test('other platforms use the Android scale', () {
    for (final p in [
      TargetPlatform.linux,
      TargetPlatform.windows,
      TargetPlatform.fuchsia,
    ]) {
      expect(map(1.0, p), 0.5);
      expect(map(0.6, p), closeTo(0.3, 1e-9));
    }
  });

  test('slow is always slower than normal', () {
    for (final p in TargetPlatform.values) {
      expect(map(0.6, p), lessThan(map(1.0, p)));
    }
  });
}
