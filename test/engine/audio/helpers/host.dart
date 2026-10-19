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

/// The real Silero VAD model if a developer fetched it (see the A1 handoff), else
/// null. `A1_SILERO_MODEL` overrides the default `.model-cache/vad/silero_vad.onnx`.
File? cachedSileroModel() {
  final f = File(
    Platform.environment['A1_SILERO_MODEL'] ??
        '.model-cache/vad/silero_vad.onnx',
  );
  return f.existsSync() ? f : null;
}

/// The tiny Silero-shaped stand-in model (see fixtures/make_tiny_vad.py).
Uint8List tinyVadBytes() =>
    File('test/engine/audio/fixtures/tiny_vad.onnx').readAsBytesSync();

/// Decodes a shared WAV fixture from test/fixtures/audio/.
PcmAudio fixture(String name) =>
    decodeWav(File('test/fixtures/audio/$name').readAsBytesSync());
