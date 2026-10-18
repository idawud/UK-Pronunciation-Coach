import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/engine/runtime/audio_input.dart';

Uint8List _wav({
  int channels = 1,
  int rate = 16000,
  int bits = 16,
  int format = 1,
  List<int> samples = const [0, 16384, -32768, 32767],
  bool extensible = false,
  bool fmtFirst = true,
  bool oddChunk = false,
}) {
  final b = BytesBuilder();
  void u32(int v) =>
      b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) =>
      b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  final data = BytesBuilder();
  for (final s in samples) {
    data.add((ByteData(2)..setInt16(0, s, Endian.little)).buffer.asUint8List());
  }
  final fmt = BytesBuilder();
  void f16(int v) => fmt.add(
    (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List(),
  );
  void f32(int v) => fmt.add(
    (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List(),
  );
  f16(extensible ? 0xFFFE : format);
  f16(channels);
  f32(rate);
  f32(rate * channels * 2);
  f16(channels * 2);
  f16(bits);
  if (extensible) {
    f16(22);
    f16(bits);
    f32(0);
    f16(format);
    fmt.add(List.filled(14, 0));
  }
  b.add('RIFF'.codeUnits);
  u32(0);
  b.add('WAVE'.codeUnits);
  if (oddChunk) {
    b.add('LIST'.codeUnits);
    u32(3);
    b.add([1, 2, 3, 0]);
  }
  void fmtChunk() {
    b.add('fmt '.codeUnits);
    u32(fmt.length);
    b.add(fmt.toBytes());
  }

  if (fmtFirst) fmtChunk();
  b.add('data'.codeUnits);
  u32(data.length);
  b.add(data.toBytes());
  if (!fmtFirst) fmtChunk();
  return b.toBytes();
}

void main() {
  group('decodePcm16Wav', () {
    test('decodes mono 16-bit samples to [-1, 1]', () {
      expect(decodePcm16Wav(_wav()), [0.0, 0.5, -1.0, closeTo(1.0, 1e-4)]);
    });

    test('averages channels and skips unknown (odd-sized) chunks', () {
      final s = decodePcm16Wav(
        _wav(channels: 2, samples: [16384, 0, -16384, -16384], oddChunk: true),
      );
      expect(s, [0.25, -0.5]);
    });

    test('accepts WAVE_FORMAT_EXTENSIBLE PCM', () {
      expect(decodePcm16Wav(_wav(extensible: true)), hasLength(4));
    });

    test('reads the shared fixture', () {
      final s = decodePcm16Wav(
        File('test/fixtures/audio/clean_read.wav').readAsBytesSync(),
      );
      expect(s.length / 16000, closeTo(3.211, 0.01));
    });

    test('rejects other formats', () {
      expect(() => decodePcm16Wav(Uint8List(4)), throwsFormatException);
      expect(() => decodePcm16Wav(_wav(rate: 44100)), throwsFormatException);
      expect(() => decodePcm16Wav(_wav(bits: 8)), throwsFormatException);
      expect(() => decodePcm16Wav(_wav(format: 3)), throwsFormatException);
      expect(() => decodePcm16Wav(_wav(channels: 0)), throwsFormatException);
      expect(
        () => decodePcm16Wav(_wav(fmtFirst: false)),
        throwsFormatException,
      );
      final noData = _wav().sublist(0, 12 + 8 + 16);
      expect(() => decodePcm16Wav(noData), throwsFormatException);
      final truncatedFmt = _wav().sublist(0, 12 + 8 + 4);
      expect(() => decodePcm16Wav(truncatedFmt), throwsFormatException);
    });
  });

  test('normaliseWaveform gives zero mean and unit variance', () {
    final x = Float32List.fromList([1, 2, 3, 4, 5]);
    final y = normaliseWaveform(x);
    final mean = y.reduce((a, b) => a + b) / y.length;
    final variance =
        y.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
        y.length;
    expect(mean, closeTo(0, 1e-6));
    expect(variance, closeTo(1, 1e-4));
    expect(x.first, 1, reason: 'input untouched');
    expect(normaliseWaveform(Float32List(0)), isEmpty);
    expect(normaliseWaveform(Float32List(3)), [
      0,
      0,
      0,
    ], reason: 'silence stays finite');
  });

  test('padToMinLength pads short input only', () {
    final short = Float32List.fromList([1, 2]);
    expect(padToMinLength(short, 4), [1, 2, 0, 0]);
    final long = Float32List(5);
    expect(identical(padToMinLength(long, 4), long), isTrue);
  });

  test('encodePcm16Wav round-trips through decodePcm16Wav', () {
    final x = Float32List.fromList([0, 0.5, -0.5, 2, -2]);
    final y = decodePcm16Wav(encodePcm16Wav(x));
    expect(y, [
      0,
      closeTo(0.5, 1e-4),
      closeTo(-0.5, 1e-4),
      closeTo(1, 1e-4),
      closeTo(-1, 1e-4),
    ]);
  });
}
