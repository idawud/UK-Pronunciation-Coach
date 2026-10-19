import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/engine/audio/wav.dart';

import 'helpers/host.dart';

Uint8List _chunk(String id, List<int> body) {
  final b = BytesBuilder()
    ..add(id.codeUnits)
    ..add(
      (ByteData(
        4,
      )..setUint32(0, body.length, Endian.little)).buffer.asUint8List(),
    )
    ..add(body);
  if (body.length.isOdd) b.addByte(0);
  return b.takeBytes();
}

Uint8List _fmt({
  int format = 1,
  int channels = 1,
  int rate = 16000,
  int bits = 16,
}) {
  final d = ByteData(16)
    ..setUint16(0, format, Endian.little)
    ..setUint16(2, channels, Endian.little)
    ..setUint32(4, rate, Endian.little)
    ..setUint32(8, rate * channels * bits ~/ 8, Endian.little)
    ..setUint16(12, channels * bits ~/ 8, Endian.little)
    ..setUint16(14, bits, Endian.little);
  return _chunk('fmt ', d.buffer.asUint8List());
}

Uint8List _riff(List<Uint8List> chunks) {
  final body = BytesBuilder()..add('WAVE'.codeUnits);
  for (final c in chunks) {
    body.add(c);
  }
  final b = body.takeBytes();
  return (BytesBuilder()
        ..add('RIFF'.codeUnits)
        ..add(
          (ByteData(
            4,
          )..setUint32(0, b.length, Endian.little)).buffer.asUint8List(),
        )
        ..add(b))
      .takeBytes();
}

Uint8List _pcm(List<int> values) {
  final d = ByteData(values.length * 2);
  for (var i = 0; i < values.length; i++) {
    d.setInt16(i * 2, values[i], Endian.little);
  }
  return d.buffer.asUint8List();
}

void main() {
  group('decodeWav', () {
    test('reads every shared fixture at 16 kHz with the manifest duration', () {
      const durations = {
        'clean_read.wav': 3211,
        'read_then_silence.wav': 5711,
        'silence.wav': 2000,
        'noise.wav': 2000,
      };
      durations.forEach((name, ms) {
        final a = fixture(name);
        expect(a.sampleRate, 16000);
        expect(a.duration.inMilliseconds, closeTo(ms, 1));
      });
    });

    test('averages channels and skips unknown chunks', () {
      final wav = _riff([
        _chunk('LIST', [1, 2, 3]),
        _fmt(channels: 2),
        _chunk('data', _pcm([16384, 0, -32768, -32768])),
      ]);
      final a = decodeWav(wav);
      expect(a.samples, [0.25, -1.0]);
    });

    test('accepts WAVE_FORMAT_EXTENSIBLE PCM', () {
      final fmt = ByteData(26)
        ..setUint16(0, 0xFFFE, Endian.little)
        ..setUint16(2, 1, Endian.little)
        ..setUint32(4, 8000, Endian.little)
        ..setUint16(14, 16, Endian.little)
        ..setUint16(24, 1, Endian.little);
      final wav = _riff([
        _chunk('fmt ', fmt.buffer.asUint8List()),
        _chunk('data', _pcm([0, 32767])),
      ]);
      final a = decodeWav(wav);
      expect(a.sampleRate, 8000);
      expect(a.samples.length, 2);
    });

    test('reads a header left with size 0 by a crashed writer', () {
      final bytes = BytesBuilder()
        ..add(wavHeader(0))
        ..add(_pcm([100, 200, 300]));
      expect(decodeWav(bytes.takeBytes()).samples.length, 3);
    });

    test('rejects malformed files', () {
      expect(() => decodeWav(Uint8List(4)), throwsFormatException);
      expect(
        () => decodeWav(
          _riff([
            _chunk('data', _pcm([1])),
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => decodeWav(
          _riff([
            _fmt(bits: 8),
            _chunk('data', [1, 2]),
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => decodeWav(
          _riff([
            _fmt(format: 3),
            _chunk('data', [1, 2]),
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => decodeWav(
          _riff([
            _fmt(channels: 0),
            _chunk('data', [1, 2]),
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => decodeWav(
          _riff([
            _chunk('fmt ', [1, 0]),
          ]),
        ),
        throwsFormatException,
      );
      expect(() => decodeWav(_riff([_fmt()])), throwsFormatException);
    });
  });

  test('encodeWav round-trips and clamps', () {
    final samples = Float32List.fromList([0, 0.5, -0.5, 2, -2]);
    final wav = encodeWav(samples);
    expect(wav.length, 44 + 10);
    final back = decodeWav(wav);
    expect(back.sampleRate, 16000);
    expect(back.samples[1], closeTo(0.5, 1e-4));
    expect(back.samples[3], closeTo(32767 / 32768, 1e-6));
    expect(back.samples[4], -1.0);
  });

  test('pcm16ToFloat ignores a trailing odd byte', () {
    final f = pcm16ToFloat(Uint8List.fromList([0, 0x40, 0, 0xC0, 7]));
    expect(f, [0.5, -0.5]);
  });

  test('durationOfSamples', () {
    expect(durationOfSamples(16000, 16000), const Duration(seconds: 1));
    expect(durationOfSamples(8, 16000), const Duration(microseconds: 500));
  });

  group('WavFileWriter', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('a1_wav'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('streams PCM and fixes the header on close', () async {
      final w = await WavFileWriter.open('${dir.path}/sub/a.wav');
      w
        ..add(_pcm([1000, 2000]))
        ..add(_pcm([3000]));
      expect(w.dataBytes, 6);
      await w.close();
      await w.close(); // idempotent
      final bytes = w.file.readAsBytesSync();
      expect(bytes.length, 50);
      final d = ByteData.sublistView(bytes);
      expect(d.getUint32(4, Endian.little), 42);
      expect(d.getUint32(40, Endian.little), 6);
      expect(decodeWav(bytes).samples.length, 3);
      expect(() => w.add(_pcm([1])), throwsStateError);
    });

    test('discard deletes the file, before or after close', () async {
      final a = await WavFileWriter.open('${dir.path}/a.wav');
      a.add(_pcm([1]));
      await a.discard();
      expect(a.file.existsSync(), isFalse);
      final b = await WavFileWriter.open('${dir.path}/b.wav');
      await b.close();
      await b.discard();
      expect(b.file.existsSync(), isFalse);
      await b.discard();
    });
  });
}
