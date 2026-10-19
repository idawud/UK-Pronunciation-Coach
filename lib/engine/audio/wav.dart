import 'dart:io';
import 'dart:typed_data';

/// Sample rate of every recording the app makes.
const int recordingSampleRate = 16000;

/// Mono PCM audio as floats in [-1, 1].
class PcmAudio {
  /// Creates the audio.
  const PcmAudio(this.samples, this.sampleRate);

  /// Mono samples in [-1, 1].
  final Float32List samples;

  /// Samples per second.
  final int sampleRate;

  /// Length of the audio.
  Duration get duration => durationOfSamples(samples.length, sampleRate);
}

/// Duration of [samples] samples at [sampleRate].
Duration durationOfSamples(int samples, int sampleRate) =>
    Duration(microseconds: samples * 1000000 ~/ sampleRate);

/// Converts little-endian 16-bit PCM bytes to floats in [-1, 1]. A trailing odd
/// byte is ignored.
Float32List pcm16ToFloat(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final n = bytes.length ~/ 2;
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

/// Decodes a 16-bit PCM WAV file (any sample rate; channels are averaged).
///
/// Throws [FormatException] for anything else.
PcmAudio decodeWav(Uint8List bytes) {
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
      if (channels < 1 || sampleRate < 1) {
        throw const FormatException('Bad channel count or sample rate');
      }
      // A header written by a crashed recorder may say 0 or too many bytes.
      final declaredEnd = body + size;
      final end = size == 0 || declaredEnd > bytes.length
          ? bytes.length
          : declaredEnd;
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
      return PcmAudio(out, sampleRate);
    }
    offset = body + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('No data chunk');
}

/// 44-byte canonical WAV header for [dataBytes] bytes of 16-bit PCM.
Uint8List wavHeader(
  int dataBytes, {
  int sampleRate = recordingSampleRate,
  int channels = 1,
}) {
  final h = ByteData(44);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      h.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  h.setUint32(4, 36 + dataBytes, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  h.setUint32(16, 16, Endian.little);
  h.setUint16(20, 1, Endian.little);
  h.setUint16(22, channels, Endian.little);
  h.setUint32(24, sampleRate, Endian.little);
  h.setUint32(28, sampleRate * channels * 2, Endian.little);
  h.setUint16(32, channels * 2, Endian.little);
  h.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  h.setUint32(40, dataBytes, Endian.little);
  return h.buffer.asUint8List();
}

/// Encodes mono float samples as a 16-bit PCM WAV file.
Uint8List encodeWav(
  Float32List samples, {
  int sampleRate = recordingSampleRate,
}) {
  final pcm = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i] * 32768).round().clamp(-32768, 32767);
    pcm.setInt16(i * 2, v, Endian.little);
  }
  return (BytesBuilder(copy: false)
        ..add(wavHeader(pcm.lengthInBytes, sampleRate: sampleRate))
        ..add(pcm.buffer.asUint8List()))
      .takeBytes();
}

/// Streams 16-bit mono PCM into a WAV file, then fixes the header sizes on [close].
class WavFileWriter {
  WavFileWriter._(this.file, this._sink, this.sampleRate);

  /// Creates (or truncates) [path] and writes a placeholder header.
  static Future<WavFileWriter> open(
    String path, {
    int sampleRate = recordingSampleRate,
  }) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final sink = file.openWrite()..add(wavHeader(0, sampleRate: sampleRate));
    return WavFileWriter._(file, sink, sampleRate);
  }

  /// The file being written.
  final File file;

  /// Sample rate written in the header.
  final int sampleRate;

  final IOSink _sink;
  int _bytes = 0;
  bool _closed = false;

  /// PCM bytes written so far.
  int get dataBytes => _bytes;

  /// Appends little-endian 16-bit PCM [bytes].
  void add(Uint8List bytes) {
    if (_closed) throw StateError('WavFileWriter closed');
    _sink.add(bytes);
    _bytes += bytes.length;
  }

  /// Flushes, closes and writes the final sizes into the header.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _sink.close();
    final raf = await file.open(mode: FileMode.append);
    try {
      await raf.setPosition(0);
      await raf.writeFrom(wavHeader(_bytes, sampleRate: sampleRate));
    } finally {
      await raf.close();
    }
  }

  /// Closes and deletes the file.
  Future<void> discard() async {
    if (!_closed) {
      _closed = true;
      await _sink.close();
    }
    if (await file.exists()) await file.delete();
  }
}
