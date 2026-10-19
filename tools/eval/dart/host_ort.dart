import 'dart:convert';
import 'dart:io';

/// Absolute path of the ONNX Runtime library the `onnxruntime_v2` plug-in ships for
/// this desktop host (Linux only), or null. `flutter test` does not build plug-ins,
/// so the library is loaded from the plug-in's folder in the pub cache (same
/// approach as A2's test helper `test/engine/runtime/helpers/host_ort.dart`).
String? hostOrtLibraryPath({
  String packageConfig = '.dart_tool/package_config.json',
}) {
  if (!Platform.isLinux) return null;
  final config = File(packageConfig);
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
