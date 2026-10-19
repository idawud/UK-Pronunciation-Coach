import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/models/enums.dart';

/// Pure signal maths for the recorder: levels, peak, SNR and the quality check.

/// Lowest level reported in dBFS; anything quieter is treated as this.
const double floorDbfs = -100.0;

/// Peak below this is [AudioQuality.tooQuiet].
const double tooQuietPeakDbfs = -30.0;

/// Estimated SNR below this is [AudioQuality.tooNoisy].
const double tooNoisySnrDb = 15.0;

/// Converts a linear amplitude (1.0 = full scale) to dBFS, floored at [floorDbfs].
double amplitudeToDbfs(double amplitude) {
  if (amplitude <= 0) return floorDbfs;
  return math.max(floorDbfs, 20 * math.log(amplitude) / math.ln10);
}

/// Maps dBFS to the `AudioRecorder.level` scale: 0.0 at -60 dB or below, 1.0 at
/// 0 dB, linear in between.
double levelFromDbfs(double dbfs) => ((dbfs + 60) / 60).clamp(0.0, 1.0);

/// Peak absolute sample of [samples] in dBFS ([floorDbfs] for empty or silent audio).
double measurePeakDbfs(Float32List samples) {
  var peak = 0.0;
  for (final s in samples) {
    final a = s.abs();
    if (a > peak) peak = a;
  }
  return amplitudeToDbfs(peak);
}

/// Root-mean-square of [samples] in dBFS.
double rmsDbfs(Float32List samples, [int start = 0, int? end]) {
  final e = end ?? samples.length;
  if (e <= start) return floorDbfs;
  var sum = 0.0;
  for (var i = start; i < e; i++) {
    sum += samples[i] * samples[i];
  }
  return amplitudeToDbfs(math.sqrt(sum / (e - start)));
}

/// Estimated signal-to-noise ratio in dB, or null when the clip is shorter than
/// [minFrames] frames.
///
/// Splits the clip into [frameSamples]-sample frames (20 ms at 16 kHz). The noise
/// power is the [noisePercentile] frame power (the quiet gaps every recording has
/// before, between and after words); the speech-plus-noise power is the
/// [signalPercentile] frame power. SNR = 10·log10((S+N)/N − 1), capped at
/// [maxSnrDb]. Needs no voice-activity detector, so it also works on noise-only
/// clips (about 0 dB).
double? estimateSnrDb(
  Float32List samples, {
  int frameSamples = 320,
  double noisePercentile = 0.10,
  double signalPercentile = 0.95,
  int minFrames = 10,
  double maxSnrDb = 90.0,
}) {
  final frames = samples.length ~/ frameSamples;
  if (frames < minFrames) return null;
  final powers = Float64List(frames);
  for (var f = 0; f < frames; f++) {
    var sum = 0.0;
    final base = f * frameSamples;
    for (var i = 0; i < frameSamples; i++) {
      final s = samples[base + i];
      sum += s * s;
    }
    // A tiny floor keeps digital silence from dividing by zero (-120 dBFS).
    powers[f] = sum / frameSamples + 1e-12;
  }
  powers.sort();
  double at(double p) => powers[((frames - 1) * p).round()];
  final noise = at(noisePercentile);
  final total = at(signalPercentile);
  final ratio = total / noise - 1;
  if (ratio <= 0) return 0.0;
  return math.min(maxSnrDb, math.max(0.0, 10 * math.log(ratio) / math.ln10));
}

/// The quality verdict for a clip: too quiet wins over too noisy.
AudioQuality classifyQuality(double peakDbfs, double? snrDb) {
  if (peakDbfs < tooQuietPeakDbfs) return AudioQuality.tooQuiet;
  if (snrDb != null && snrDb < tooNoisySnrDb) return AudioQuality.tooNoisy;
  return AudioQuality.ok;
}

/// Peak, SNR and verdict for one clip.
class QualityReport {
  /// Creates the report.
  const QualityReport(this.peakDbfs, this.snrDb, this.quality);

  /// Measures [samples].
  factory QualityReport.of(Float32List samples) {
    final peak = measurePeakDbfs(samples);
    final snr = estimateSnrDb(samples);
    return QualityReport(peak, snr, classifyQuality(peak, snr));
  }

  /// Peak level in dBFS (<= 0).
  final double peakDbfs;

  /// Estimated SNR in dB, null for very short clips.
  final double? snrDb;

  /// Verdict.
  final AudioQuality quality;
}

/// Turns incoming samples into level values, one per [windowSamples] samples
/// (800 = 50 ms at 16 kHz, i.e. 20 values per second). Each value is the window's
/// RMS mapped with [levelFromDbfs].
class LevelMeter {
  /// Creates a meter.
  LevelMeter({this.windowSamples = 800});

  /// Samples per level value.
  final int windowSamples;

  double _sum = 0;
  int _count = 0;

  /// Adds [samples] and returns the level values completed by them (often none).
  List<double> add(Float32List samples) {
    final out = <double>[];
    for (final s in samples) {
      _sum += s * s;
      if (++_count == windowSamples) {
        out.add(
          levelFromDbfs(amplitudeToDbfs(math.sqrt(_sum / windowSamples))),
        );
        _sum = 0;
        _count = 0;
      }
    }
    return out;
  }

  /// Forgets any partial window.
  void reset() {
    _sum = 0;
    _count = 0;
  }
}
