import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:uk_pronunciation_coach/engine/audio/wav.dart';

/// Path of the ONNX Runtime library the `onnxruntime_v2` plug-in ships for this
/// Linux host (straight from the pub cache: `flutter test` builds no plug-ins), or
/// null on other hosts.
String? hostOrtLibraryPath() {
  if (!Platform.isLinux) return null;
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;
  final json = jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
  for (final p in json['packages'] as List<dynamic>) {
    final pkg = p as Map<String, dynamic>;
    if (pkg['name'] != 'onnxruntime_v2') continue;
    final root = Uri.parse(pkg['rootUri'] as String);
    final dir = Directory.fromUri(
      root.isAbsolute ? root : config.parent.uri.resolveUri(root),
    );
    final linux = Directory('${dir.path}/linux');
    if (!linux.existsSync()) return null;
    for (final f in linux.listSync()) {
      if (f is File && f.path.contains('libonnxruntime.so')) return f.path;
    }
  }
  return null;
}

/// The real Silero VAD model: `A1_SILERO_MODEL` if set, else the bundled
/// `assets/models/silero_vad.onnx` (committed by I1), else a developer's
/// `.model-cache/vad/silero_vad.onnx`; null when none exists.
File? cachedSileroModel() {
  final override = Platform.environment['A1_SILERO_MODEL'];
  for (final path in [
    ?override,
    if (override == null) ...[
      'assets/models/silero_vad.onnx',
      '.model-cache/vad/silero_vad.onnx',
    ],
  ]) {
    final f = File(path);
    if (f.existsSync()) return f;
  }
  return null;
}

/// The tiny Silero-shaped stand-in model (see fixtures/make_tiny_vad.py).
Uint8List tinyVadBytes() =>
    File('test/engine/audio/fixtures/tiny_vad.onnx').readAsBytesSync();

/// Decodes a shared WAV fixture from test/fixtures/audio/.
PcmAudio fixture(String name) =>
    decodeWav(File('test/fixtures/audio/$name').readAsBytesSync());
