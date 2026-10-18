import 'dart:math' as math;
import 'dart:typed_data';

/// Sample rate the phoneme models expect.
const int modelSampleRate = 16000;

/// Decodes a 16-bit PCM WAV file into mono samples in [-1, 1].
///
/// Accepts any channel count (channels are averaged) but only [modelSampleRate];
/// resampling is not done here because the app always records at 16 kHz.
/// Throws [FormatException] for anything else.
Float32List decodePcm16Wav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  String tag(int at) => String.fromCharCodes(bytes, at, at + 4);
  if (bytes.length < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
    throw const FormatException('Not a RIFF/WAVE file');
  }
  int? channels;
  int? sampleRate;
  int? bits;
  int? format;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = tag(offset);
    final size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      if (size < 16 || body + 16 > bytes.length) {
        throw const FormatException('Truncated fmt chunk');
      }
      format = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
      if (format == 0xFFFE && size >= 26) {
        // WAVE_FORMAT_EXTENSIBLE: the real format is the sub-format GUID's first word.
        format = data.getUint16(body + 24, Endian.little);
      }
    } else if (id == 'data') {
      if (channels == null || sampleRate == null || bits == null) {
        throw const FormatException('data chunk before fmt chunk');
      }
      if (format != 1 || bits != 16) {
        throw FormatException(
          'Only 16-bit PCM is supported (format $format, $bits bits)',
        );
      }
      if (channels < 1) throw const FormatException('No channels');
      if (sampleRate != modelSampleRate) {
        throw FormatException(
          'Expected $modelSampleRate Hz audio, got $sampleRate Hz',
        );
      }
      final end = math.min(body + size, bytes.length);
      final frames = (end - body) ~/ (2 * channels);
      final out = Float32List(frames);
      var p = body;
      for (var i = 0; i < frames; i++) {
        var sum = 0;
        for (var c = 0; c < channels; c++) {
          sum += data.getInt16(p, Endian.little);
          p += 2;
        }
        out[i] = sum / (channels * 32768.0);
      }
      return out;
    }
    offset = body + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('No data chunk');
}

/// Zero-mean / unit-variance normalisation, as Hugging Face's
/// `Wav2Vec2FeatureExtractor(do_normalize=True)` does: `(x - mean) / sqrt(var + 1e-7)`.
Float32List normaliseWaveform(Float32List samples) {
  final n = samples.length;
  final out = Float32List(n);
  if (n == 0) return out;
  var mean = 0.0;
  for (final s in samples) {
    mean += s;
  }
  mean /= n;
  var variance = 0.0;
  for (final s in samples) {
    final d = s - mean;
    variance += d * d;
  }
  variance /= n;
  final scale = 1 / math.sqrt(variance + 1e-7);
  for (var i = 0; i < n; i++) {
    out[i] = (samples[i] - mean) * scale;
  }
  return out;
}

/// Pads [samples] with zeros up to [minLength] (the model's receptive field: a
/// wav2vec2 feature encoder needs at least 400 samples to emit one frame).
Float32List padToMinLength(Float32List samples, int minLength) {
  if (samples.length >= minLength) return samples;
  return Float32List(minLength)..setRange(0, samples.length, samples);
}

/// Encodes mono [samples] in [-1, 1] as a 16-bit PCM WAV at [sampleRate].
Uint8List encodePcm16Wav(
  Float32List samples, {
  int sampleRate = modelSampleRate,
}) {
  final dataBytes = samples.length * 2;
  final out = ByteData(44 + dataBytes);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      out.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  out.setUint32(4, 36 + dataBytes, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  out
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  tag(36, 'data');
  out.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    out.setInt16(44 + i * 2, v, Endian.little);
  }
  return out.buffer.asUint8List();
}
