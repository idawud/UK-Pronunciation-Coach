import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../../core/models/enums.dart';

/// The hardware facts the tier choice depends on.
class DeviceSnapshot {
  /// Creates a snapshot.
  const DeviceSnapshot({
    required this.platform,
    this.ramMb,
    this.androidSdk,
    this.iosMachine,
  });

  /// `android`, `ios` or another `Platform.operatingSystem` value.
  final String platform;

  /// Physical RAM in MB, if known.
  final int? ramMb;

  /// Android API level, if Android.
  final int? androidSdk;

  /// iOS hardware identifier such as `iPhone11,2`, if iOS.
  final String? iosMachine;
}

/// Reads a [DeviceSnapshot].
abstract interface class DeviceInfoSource {
  /// The current device.
  Future<DeviceSnapshot> read();
}

/// [DeviceInfoSource] on the `device_info_plus` plug-in.
class PluginDeviceInfoSource implements DeviceInfoSource {
  /// Creates the source; [plugin] is injectable for tests.
  PluginDeviceInfoSource({DeviceInfoPlugin? plugin, String? platform})
    : _plugin = plugin ?? DeviceInfoPlugin(),
      _platform = platform ?? Platform.operatingSystem;

  final DeviceInfoPlugin _plugin;
  final String _platform;

  @override
  Future<DeviceSnapshot> read() async {
    switch (_platform) {
      case 'android':
        final a = await _plugin.androidInfo;
        return DeviceSnapshot(
          platform: 'android',
          ramMb: a.physicalRamSize > 0 ? a.physicalRamSize : null,
          androidSdk: a.version.sdkInt,
        );
      case 'ios':
        final i = await _plugin.iosInfo;
        return DeviceSnapshot(
          platform: 'ios',
          ramMb: i.physicalRamSize > 0 ? i.physicalRamSize : null,
          iosMachine: i.utsname.machine,
        );
      default:
        return DeviceSnapshot(platform: _platform);
    }
  }
}

/// Picks the tier from hardware alone, or null when unsure.
///
/// - Under [minFullRamMb] of RAM: light. A phone sold as "4 GB" reports about
///   3.5-3.8 GB, so the cut-off sits below 4096.
/// - Android older than 10 (API 29): light.
/// - iPhone older than the XS generation (`iPhone11,x`): light. iPads and newer
///   iPhones are judged by RAM.
/// - Otherwise full when RAM is known; null (benchmark) when it is not.
ModelTier? tierFromDevice(DeviceSnapshot d) {
  final ram = d.ramMb;
  if (ram != null && ram < minFullRamMb) return ModelTier.light;
  if (d.platform == 'android') {
    final sdk = d.androidSdk;
    if (sdk != null && sdk < 29) return ModelTier.light;
  }
  if (d.platform == 'ios') {
    final m = RegExp(r'^iPhone(\d+),').firstMatch(d.iosMachine ?? '');
    if (m != null && int.parse(m.group(1)!) < 11) return ModelTier.light;
  }
  return ram == null ? null : ModelTier.full;
}

/// RAM below which the light tier is chosen.
const int minFullRamMb = 3400;

/// Light-tier time for a 5 s clip below which the device counts as fast enough for
/// the full tier. The full model (wav2vec2 large, ~315 M parameters) is roughly 3x
/// the work of the light one (base, ~95 M); the target is a 25 s passage in 2.5 s on
/// the full tier, i.e. 0.5 s per 5 s, so the light model must manage 5 s in ~0.17 s.
const Duration fastEnoughFor5s = Duration(milliseconds: 170);

/// Decides and caches the recommended tier.
class TierAdvisor {
  /// Creates the advisor. [benchmark] times the light model on 5 s of audio (null
  /// when it cannot run); [cacheFile] stores the answer across launches.
  TierAdvisor({
    required this._device,
    required this._benchmark,
    required this.cacheFile,
  });

  final DeviceInfoSource _device;
  final Future<Duration?> Function() _benchmark;

  /// Where the answer is cached.
  final File cacheFile;

  Future<ModelTier>? _answer;

  /// The recommended tier (cached after the first call).
  Future<ModelTier> recommend() => _answer ??= _decide();

  Future<ModelTier> _decide() async {
    final cached = _readCache();
    if (cached != null) return cached;
    String reason;
    ModelTier? tier;
    try {
      tier = tierFromDevice(await _device.read());
      reason = 'device';
    } on Object catch (e) {
      reason = 'device info failed: $e';
    }
    if (tier == null) {
      final time = await _benchmark();
      if (time == null) {
        tier = ModelTier.light;
        reason = 'no benchmark';
      } else {
        tier = time <= fastEnoughFor5s ? ModelTier.full : ModelTier.light;
        reason = 'benchmark ${time.inMilliseconds} ms per 5 s';
      }
    }
    _writeCache(tier, reason);
    return tier;
  }

  ModelTier? _readCache() {
    try {
      if (!cacheFile.existsSync()) return null;
      final json =
          jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
      final name = json['tier'];
      return ModelTier.values.where((t) => t.name == name).firstOrNull;
    } on Object {
      return null;
    }
  }

  void _writeCache(ModelTier tier, String reason) {
    try {
      cacheFile.parent.createSync(recursive: true);
      cacheFile.writeAsStringSync(
        jsonEncode({'tier': tier.name, 'reason': reason}),
      );
    } on FileSystemException {
      // Not fatal: the answer is recomputed next launch.
    }
  }
}
