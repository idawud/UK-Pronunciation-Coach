import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/enums.dart';
import 'package:uk_pronunciation_coach/engine/audio/signal.dart';

import 'helpers/host.dart';

void main() {
  final manifest = jsonDecode(
    File('test/fixtures/audio/manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('dBFS conversions', () {
    expect(amplitudeToDbfs(1), 0);
    expect(amplitudeToDbfs(0.5), closeTo(-6.02, 0.01));
    expect(amplitudeToDbfs(0), floorDbfs);
    expect(amplitudeToDbfs(1e-9), floorDbfs);
    expect(levelFromDbfs(0), 1);
    expect(levelFromDbfs(-30), 0.5);
    expect(levelFromDbfs(-80), 0);
    expect(levelFromDbfs(3), 1);
    expect(rmsDbfs(Float32List(0)), floorDbfs);
    expect(rmsDbfs(Float32List.fromList([0.5, -0.5])), closeTo(-6.02, 0.01));
    expect(measurePeakDbfs(Float32List(0)), floorDbfs);
  });

  group('every shared fixture', () {
    for (final entry in manifest.entries) {
      final name = entry.key;
      final m = entry.value as Map<String, dynamic>;
      test('$name: peak and quality match the manifest', () {
        final report = QualityReport.of(fixture(name).samples);
        expect(
          report.peakDbfs,
          closeTo((m['peakDbfs'] as num).toDouble(), 0.2),
        );
        expect(report.quality.name, m['expectedQuality']);
        expect(report.peakDbfs, lessThanOrEqualTo(0));
      });
    }
  });

  test('SNR estimates: clean high, noisy low, noise about 0', () {
    expect(estimateSnrDb(fixture('clean_read.wav').samples), greaterThan(40));
    final noisy = estimateSnrDb(fixture('noisy_read.wav').samples)!;
    expect(noisy, inInclusiveRange(3, 12));
    expect(estimateSnrDb(fixture('noise.wav').samples), lessThan(3));
    expect(estimateSnrDb(Float32List(320 * 9)), isNull);
    expect(estimateSnrDb(Float32List(320 * 20)), 0);
  });

  test('classifyQuality: too quiet wins, null SNR is ok', () {
    expect(classifyQuality(-31, 40), AudioQuality.tooQuiet);
    expect(classifyQuality(-31, 3), AudioQuality.tooQuiet);
    expect(classifyQuality(-10, 14.9), AudioQuality.tooNoisy);
    expect(classifyQuality(-10, 15), AudioQuality.ok);
    expect(classifyQuality(-10, null), AudioQuality.ok);
  });

  test('LevelMeter emits 20 values per second of audio', () {
    final meter = LevelMeter();
    final tone = Float32List.fromList([
      for (var i = 0; i < 16000; i++) 0.5 * math.sin(i * 0.1),
    ]);
    final values = <double>[
      ...meter.add(Float32List.sublistView(tone, 0, 700)),
      ...meter.add(Float32List.sublistView(tone, 700)),
    ];
    expect(values.length, 20);
    // 0.5-amplitude sine: RMS -9 dBFS -> 0.85.
    for (final v in values) {
      expect(v, closeTo(0.85, 0.01));
    }
    meter
      ..add(Float32List(400))
      ..reset();
    expect(meter.add(Float32List(799)), isEmpty);
    expect(meter.add(Float32List(1)), [0.0]);
  });
}
