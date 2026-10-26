import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/engine/runtime/cpu_cores.dart';
import 'package:uk_pronunciation_coach/engine/runtime/execution_providers.dart';

void main() {
  const all = {
    'CPUExecutionProvider',
    'XnnpackExecutionProvider',
    'NnapiExecutionProvider',
    'CoreMLExecutionProvider',
  };

  group('InferenceAccelerator.parse', () {
    test('reads names, ignoring case and spaces', () {
      expect(
        InferenceAccelerator.parse(' XNNPACK '),
        InferenceAccelerator.xnnpack,
      );
      expect(InferenceAccelerator.parse('nnapi'), InferenceAccelerator.nnapi);
      expect(InferenceAccelerator.parse('coreml'), InferenceAccelerator.coreml);
      expect(InferenceAccelerator.parse('cpu'), InferenceAccelerator.cpu);
    });
    test('empty and unknown values are null', () {
      expect(InferenceAccelerator.parse(''), isNull);
      expect(InferenceAccelerator.parse('gpu'), isNull);
    });
  });

  group('acceleratorPlan', () {
    test('defaults to CPU only', () {
      expect(acceleratorPlan(os: 'android', available: all), isEmpty);
      expect(
        acceleratorPlan(
          os: 'android',
          available: all,
          requested: InferenceAccelerator.cpu,
        ),
        isEmpty,
      );
    });
    test('uses a requested provider the library has', () {
      expect(
        acceleratorPlan(
          os: 'android',
          available: all,
          requested: InferenceAccelerator.xnnpack,
        ),
        [InferenceAccelerator.xnnpack],
      );
      expect(
        acceleratorPlan(
          os: 'android',
          available: all,
          requested: InferenceAccelerator.nnapi,
        ),
        [InferenceAccelerator.nnapi],
      );
      expect(
        acceleratorPlan(
          os: 'ios',
          available: all,
          requested: InferenceAccelerator.coreml,
        ),
        [InferenceAccelerator.coreml],
      );
    });
    test('skips a provider the library was built without', () {
      expect(
        acceleratorPlan(
          os: 'android',
          available: const {'CPUExecutionProvider'},
          requested: InferenceAccelerator.xnnpack,
        ),
        isEmpty,
      );
    });
    test('skips a provider the platform cannot have', () {
      expect(
        acceleratorPlan(
          os: 'ios',
          available: all,
          requested: InferenceAccelerator.nnapi,
        ),
        isEmpty,
      );
      expect(
        acceleratorPlan(
          os: 'android',
          available: all,
          requested: InferenceAccelerator.coreml,
        ),
        isEmpty,
      );
      expect(
        acceleratorPlan(
          os: 'linux',
          available: all,
          requested: InferenceAccelerator.coreml,
        ),
        isEmpty,
      );
    });
  });

  group('bigCoreCountFromCpufreq', () {
    int? count(List<int?> maxKhz) => bigCoreCountFromCpufreq(
      cpuCount: maxKhz.length,
      read: (path) {
        final i = int.parse(RegExp(r'cpu(\d+)/').firstMatch(path)!.group(1)!);
        final f = maxKhz[i];
        return f == null ? null : '$f\n';
      },
    );
    test('counts the cores faster than the slowest', () {
      expect(
        count([
          1800000,
          1800000,
          1800000,
          1800000,
          2350000,
          2350000,
          2850000,
          2850000,
        ]),
        4,
      );
      expect(
        count([
          2000000,
          2000000,
          2000000,
          2000000,
          2000000,
          2000000,
          2200000,
          2200000,
        ]),
        2,
      );
    });
    test('equal cores all count', () {
      expect(count([2000000, 2000000, 2000000, 2000000]), 4);
    });
    test('unreadable data is null', () {
      expect(count([null, null]), isNull);
    });
  });

  group('inferenceThreadsFor', () {
    test('Android: big cores, within 1..4', () {
      expect(
        inferenceThreadsFor(os: 'android', processors: 8, bigCores: () => 2),
        2,
      );
      expect(
        inferenceThreadsFor(os: 'android', processors: 8, bigCores: () => 6),
        4,
      );
      expect(
        inferenceThreadsFor(os: 'android', processors: 8, bigCores: () => 0),
        1,
      );
    });
    test('unknown big cores: all cores, capped', () {
      expect(
        inferenceThreadsFor(os: 'android', processors: 8, bigCores: () => null),
        4,
      );
      expect(
        inferenceThreadsFor(os: 'linux', processors: 2, bigCores: () => null),
        2,
      );
    });
    test('Apple: performance cores', () {
      expect(
        inferenceThreadsFor(os: 'ios', processors: 6, appleCores: () => 2),
        2,
      );
      expect(
        inferenceThreadsFor(os: 'macos', processors: 12, appleCores: () => 8),
        4,
      );
      expect(
        inferenceThreadsFor(os: 'ios', processors: 6, appleCores: () => null),
        4,
      );
    });
    test('other platforms: processors, capped', () {
      expect(inferenceThreadsFor(os: 'windows', processors: 16), 4);
      expect(inferenceThreadsFor(os: 'windows', processors: 1), 1);
    });
  });

  test('appleCoreCount reads the performance level, ignoring bad values', () {
    expect(
      appleCoreCount(read: (n) => n == 'hw.perflevel0.physicalcpu' ? 2 : null),
      2,
    );
    expect(appleCoreCount(read: (_) => 0), isNull);
    expect(appleCoreCount(read: (_) => null), isNull);
  });
}
