import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';

/// Most intra-op threads ONNX Runtime gets: phones have at most 4 fast cores, and
/// more threads mostly contend with the UI and audio threads.
const int maxInferenceThreads = 4;

/// Reads one file's text, or null when it cannot be read.
typedef TextFileReader = String? Function(String path);

String? _readText(String path) {
  try {
    return File(path).readAsStringSync();
  } on Object {
    return null;
  }
}

/// Number of "big" CPU cores from Linux / Android cpufreq data: cores whose maximum
/// frequency is above the slowest core's (the LITTLE cluster is left out). All
/// cores when they share one maximum. Null when cpufreq cannot be read.
///
/// Examples (max GHz per core): Tensor G2 2x2.85 + 2x2.35 + 4x1.8 -> 4;
/// Dimensity 700 2x2.2 + 6x2.0 -> 2; Snapdragon 778G 1x2.4 + 3x2.2 + 4x1.9 -> 4.
int? bigCoreCountFromCpufreq({
  String root = '/sys/devices/system/cpu',
  TextFileReader read = _readText,
  int? cpuCount,
}) {
  final n = cpuCount ?? Platform.numberOfProcessors;
  final freqs = <int>[];
  for (var i = 0; i < n; i++) {
    final text = read('$root/cpu$i/cpufreq/cpuinfo_max_freq');
    final f = text == null ? null : int.tryParse(text.trim());
    if (f != null && f > 0) freqs.add(f);
  }
  if (freqs.isEmpty) return null;
  final slowest = freqs.reduce(math.min);
  final big = freqs.where((f) => f > slowest).length;
  return big == 0 ? freqs.length : big;
}

/// Reads an integer `sysctl` value by name (Apple platforms), or null.
typedef SysctlReader = int? Function(String name);

int? _sysctlInt(String name) {
  try {
    final lib = ffi.DynamicLibrary.process();
    final fn = lib
        .lookupFunction<
          ffi.Int Function(
            ffi.Pointer<Utf8>,
            ffi.Pointer<ffi.Void>,
            ffi.Pointer<ffi.Size>,
            ffi.Pointer<ffi.Void>,
            ffi.Size,
          ),
          int Function(
            ffi.Pointer<Utf8>,
            ffi.Pointer<ffi.Void>,
            ffi.Pointer<ffi.Size>,
            ffi.Pointer<ffi.Void>,
            int,
          )
        >('sysctlbyname');
    return using((arena) {
      final value = arena<ffi.Int32>();
      final size = arena<ffi.Size>()..value = 4;
      final rc = fn(
        name.toNativeUtf8(allocator: arena),
        value.cast(),
        size,
        ffi.nullptr,
        0,
      );
      return rc == 0 ? value.value : null;
    });
  } on Object {
    return null;
  }
}

/// Performance cores on Apple chips (`hw.perflevel0.physicalcpu`: 2 on A12-A18
/// iPhones, 4-12 on M-series), or null when the value is not available.
int? appleCoreCount({SysctlReader read = _sysctlInt}) {
  final p = read('hw.perflevel0.physicalcpu');
  return p != null && p > 0 ? p : null;
}

/// ONNX Runtime intra-op threads for this device: its big / performance cores,
/// between 1 and [maxInferenceThreads]; all cores (capped) when that is unknown.
int inferenceThreadsFor({
  required String os,
  required int processors,
  int? Function()? bigCores,
  int? Function()? appleCores,
}) {
  int? fast;
  if (os == 'android' || os == 'linux') {
    fast = (bigCores ?? () => bigCoreCountFromCpufreq(cpuCount: processors))();
  } else if (os == 'ios' || os == 'macos') {
    fast = (appleCores ?? appleCoreCount)();
  }
  return math.max(1, math.min(maxInferenceThreads, fast ?? processors));
}
