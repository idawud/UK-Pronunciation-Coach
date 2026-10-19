import 'dart:convert';
import 'dart:io';

import 'package:uk_pronunciation_coach/engine/runtime/ctc_session.dart';

/// Absolute path of the ONNX Runtime library that the `onnxruntime_v2` plug-in
/// ships for this desktop host, or null when there is none (non-Linux hosts).
///
/// `flutter test` does not build plug-ins, so the library is loaded straight from
/// the plug-in's folder in the pub cache.
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

/// Opener for the host library (sendable to the inference isolate).
CtcModelSession hostOpener(String modelPath) => OrtCtcModelSession.open(
  modelPath,
  libraryPath: hostOrtLibraryPath(),
  threads: 4,
);
