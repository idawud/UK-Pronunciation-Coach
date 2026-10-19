import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/runtime/tier_advisor.dart';

import 'helpers/fakes.dart';

class _ThrowingDevice implements DeviceInfoSource {
  @override
  Future<DeviceSnapshot> read() async => throw StateError('no plug-in');
}

AndroidDeviceInfo _android({required int sdk, required int ram}) =>
    AndroidDeviceInfo.setMockInitialValues(
      version: AndroidBuildVersion.setMockInitialValues(
        codename: 'REL',
        incremental: '1',
        previewSdkInt: 0,
        release: '14',
        sdkInt: sdk,
      ),
      board: '',
      bootloader: '',
      brand: '',
      device: '',
      display: '',
      fingerprint: '',
      hardware: '',
      host: '',
      id: '',
      manufacturer: '',
      model: '',
      product: '',
      name: '',
      supported32BitAbis: const [],
      supported64BitAbis: const [],
      supportedAbis: const [],
      tags: '',
      time: 0,
      type: '',
      isPhysicalDevice: true,
      freeDiskSize: 0,
      totalDiskSize: 0,
      systemFeatures: const [],
      isLowRamDevice: false,
      physicalRamSize: ram,
      availableRamSize: 0,
    );

IosDeviceInfo _ios({required String machine, required int ram}) =>
    IosDeviceInfo.setMockInitialValues(
      name: '',
      systemName: 'iOS',
      systemVersion: '17.0',
      model: 'iPhone',
      modelName: '',
      localizedModel: '',
      freeDiskSize: 0,
      totalDiskSize: 0,
      isPhysicalDevice: true,
      isiOSAppOnMac: false,
      isiOSAppOnVision: false,
      physicalRamSize: ram,
      availableRamSize: 0,
      utsname: IosUtsname.setMockInitialValues(
        sysname: '',
        nodename: '',
        release: '',
        version: '',
        machine: machine,
      ),
    );

void main() {
  group('tierFromDevice', () {
    ModelTier? t(DeviceSnapshot d) => tierFromDevice(d);

    test('low RAM is light on any platform', () {
      expect(
        t(
          const DeviceSnapshot(
            platform: 'android',
            ramMb: 2900,
            androidSdk: 34,
          ),
        ),
        ModelTier.light,
      );
      expect(
        t(
          const DeviceSnapshot(
            platform: 'ios',
            ramMb: 3000,
            iosMachine: 'iPhone14,2',
          ),
        ),
        ModelTier.light,
      );
    });

    test('a 4 GB phone (about 3.7 GB reported) gets full', () {
      expect(
        t(
          const DeviceSnapshot(
            platform: 'android',
            ramMb: 3700,
            androidSdk: 30,
          ),
        ),
        ModelTier.full,
      );
    });

    test('Android older than 10 is light', () {
      expect(
        t(
          const DeviceSnapshot(
            platform: 'android',
            ramMb: 6000,
            androidSdk: 28,
          ),
        ),
        ModelTier.light,
      );
      expect(
        t(
          const DeviceSnapshot(
            platform: 'android',
            ramMb: 6000,
            androidSdk: 29,
          ),
        ),
        ModelTier.full,
      );
    });

    test('iPhone older than XS is light; XS and iPads by RAM', () {
      expect(
        t(
          const DeviceSnapshot(
            platform: 'ios',
            ramMb: 4000,
            iosMachine: 'iPhone10,3',
          ),
        ),
        ModelTier.light,
      );
      expect(
        t(
          const DeviceSnapshot(
            platform: 'ios',
            ramMb: 4000,
            iosMachine: 'iPhone11,2',
          ),
        ),
        ModelTier.full,
      );
      expect(
        t(
          const DeviceSnapshot(
            platform: 'ios',
            ramMb: 8000,
            iosMachine: 'iPad8,1',
          ),
        ),
        ModelTier.full,
      );
    });

    test('unknown RAM is unsure (benchmark decides)', () {
      expect(t(const DeviceSnapshot(platform: 'linux')), isNull);
      expect(
        t(const DeviceSnapshot(platform: 'android', androidSdk: 33)),
        isNull,
      );
    });
  });

  group('PluginDeviceInfoSource', () {
    test('reads Android RAM and SDK', () async {
      final plugin = DeviceInfoPlugin.setMockInitialValues(
        androidDeviceInfo: _android(sdk: 33, ram: 5800),
      );
      final d = await PluginDeviceInfoSource(
        plugin: plugin,
        platform: 'android',
      ).read();
      expect((d.platform, d.ramMb, d.androidSdk), ('android', 5800, 33));
    });

    test('reads iOS RAM and machine; zero RAM means unknown', () async {
      final plugin = DeviceInfoPlugin.setMockInitialValues(
        iosDeviceInfo: _ios(machine: 'iPhone11,2', ram: 0),
      );
      final d = await PluginDeviceInfoSource(
        plugin: plugin,
        platform: 'ios',
      ).read();
      expect((d.platform, d.ramMb, d.iosMachine), ('ios', null, 'iPhone11,2'));
    });

    test('other platforms report only the platform', () async {
      final d = await PluginDeviceInfoSource(platform: 'linux').read();
      expect((d.platform, d.ramMb), ('linux', null));
    });
  });

  group('TierAdvisor', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('a2_tier'));
    tearDown(() => tmp.delete(recursive: true));

    File cache() => File('${tmp.path}/sub/tier.json');

    test('uses the device answer, caches it and does not benchmark', () async {
      var benchmarks = 0;
      final device = FakeDeviceInfo(
        const DeviceSnapshot(platform: 'android', ramMb: 2000, androidSdk: 33),
      );
      final a = TierAdvisor(
        device: device,
        benchmark: () async {
          benchmarks++;
          return Duration.zero;
        },
        cacheFile: cache(),
      );
      expect(await a.recommend(), ModelTier.light);
      expect(await a.recommend(), ModelTier.light);
      expect((device.reads, benchmarks), (1, 0));
      expect(cache().readAsStringSync(), contains('"light"'));

      // A new advisor (next launch) reads the cache, not the device.
      final next = TierAdvisor(
        device: device,
        benchmark: () async => null,
        cacheFile: cache(),
      );
      expect(await next.recommend(), ModelTier.light);
      expect(device.reads, 1);
    });

    test('benchmarks when the device is unsure', () async {
      final unsure = FakeDeviceInfo(const DeviceSnapshot(platform: 'linux'));
      Future<ModelTier> run(Duration? time) {
        if (cache().existsSync()) cache().deleteSync();
        return TierAdvisor(
          device: unsure,
          benchmark: () async => time,
          cacheFile: cache(),
        ).recommend();
      }

      expect(await run(const Duration(milliseconds: 100)), ModelTier.full);
      expect(cache().readAsStringSync(), contains('benchmark 100 ms'));
      expect(await run(const Duration(milliseconds: 900)), ModelTier.light);
      expect(await run(null), ModelTier.light);
    });

    test('device info failure falls back to the benchmark', () async {
      final a = TierAdvisor(
        device: _ThrowingDevice(),
        benchmark: () async => const Duration(milliseconds: 50),
        cacheFile: cache(),
      );
      expect(await a.recommend(), ModelTier.full);
    });

    test(
      'a corrupt cache is ignored; an unwritable cache is not fatal',
      () async {
        cache()
          ..createSync(recursive: true)
          ..writeAsStringSync('{bad');
        final a = TierAdvisor(
          device: FakeDeviceInfo(),
          benchmark: () async => null,
          cacheFile: cache(),
        );
        expect(await a.recommend(), ModelTier.full);

        // Parent "directory" is a file, so the cache cannot be written.
        final blocker = File('${tmp.path}/blocker')..writeAsStringSync('x');
        final b = TierAdvisor(
          device: FakeDeviceInfo(),
          benchmark: () async => null,
          cacheFile: File('${blocker.path}/tier.json'),
        );
        expect(await b.recommend(), ModelTier.full);
      },
    );
  });
}
