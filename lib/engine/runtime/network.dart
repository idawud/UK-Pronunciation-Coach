import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

/// A response body opened by [ModelTransport.get].
class ModelResponse {
  /// Creates a response.
  const ModelResponse({
    required this.body,
    required this.resumed,
    this.contentLength,
  });

  /// The bytes, starting at the requested offset when [resumed], else at 0.
  final Stream<List<int>> body;

  /// True when the server honoured the requested offset (HTTP 206).
  final bool resumed;

  /// Length of [body] in bytes, if known.
  final int? contentLength;
}

/// Fetches model files. The only network access in the app (A2's one-time full-model
/// download); tests inject a local or in-memory transport.
abstract interface class ModelTransport {
  /// Opens [url] from byte [offset] (a `Range` request when > 0). Throws
  /// [HttpException] or [SocketException] on failure.
  Future<ModelResponse> get(Uri url, {int offset = 0});
}

/// [ModelTransport] over HTTPS with `dart:io`'s [HttpClient] (follows the redirects
/// GitHub Release assets use).
class HttpModelTransport implements ModelTransport {
  /// Creates the transport; pass [client] to customise timeouts or proxies.
  HttpModelTransport({HttpClient? client})
    : _client =
          client ??
          (HttpClient()..connectionTimeout = const Duration(seconds: 20));

  final HttpClient _client;

  @override
  Future<ModelResponse> get(Uri url, {int offset = 0}) async {
    final request = await _client.getUrl(url);
    if (offset > 0) {
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
    }
    final response = await request.close();
    final status = response.statusCode;
    if (status != HttpStatus.ok && status != HttpStatus.partialContent) {
      await response.drain<void>();
      throw HttpException('HTTP $status', uri: url);
    }
    return ModelResponse(
      body: response,
      resumed: status == HttpStatus.partialContent,
      contentLength: response.contentLength >= 0
          ? response.contentLength
          : null,
    );
  }
}

/// Whether the device is on an unmetered (Wi-Fi / Ethernet) connection.
abstract interface class NetworkMonitor {
  /// The current answer.
  Future<bool> isUnmetered();

  /// Emits the new answer whenever connectivity changes.
  Stream<bool> get unmeteredChanges;
}

/// [NetworkMonitor] that always says yes (desktop, tests).
class AlwaysUnmetered implements NetworkMonitor {
  /// Creates the monitor.
  const AlwaysUnmetered();

  @override
  Future<bool> isUnmetered() async => true;

  @override
  Stream<bool> get unmeteredChanges => const Stream.empty();
}

/// Lists the device's network interfaces (injectable for tests).
typedef InterfaceLister = Future<List<NetworkInterface>> Function();

Future<List<NetworkInterface>> _listInterfaces() =>
    NetworkInterface.list(includeLinkLocal: false);

/// [NetworkMonitor] from the OS network interfaces (`dart:io`, no plug-in): the
/// connection counts as unmetered when a Wi-Fi or Ethernet interface has a routable
/// address (Android `wlan*` / `eth*`, iOS / macOS `en*`, Linux `wl*` / `en*` /
/// `eth*`). Cellular interfaces (`rmnet*`, `ccmni*`, `pdp_ip*`), VPN tunnels and
/// loopback do not count. Changes are found by polling every [interval].
///
/// Limits: it sees which interfaces are up, not which one carries traffic, so a
/// phone sharing its mobile data as a hotspot (on `wlan*` / `ap*`) or joined to a
/// Wi-Fi without internet looks unmetered; it cannot see Android's "metered Wi-Fi"
/// flag. On phones [ConnectivityNetworkMonitor] is preferred and uses this only as
/// a fallback (see [platformNetworkMonitor]).
class InterfaceNetworkMonitor implements NetworkMonitor {
  /// Creates the monitor.
  InterfaceNetworkMonitor({
    InterfaceLister? lister,
    this.interval = const Duration(seconds: 5),
  }) : _lister = lister ?? _listInterfaces;

  final InterfaceLister _lister;

  /// Poll interval for [unmeteredChanges].
  final Duration interval;

  static final _unmeteredName = RegExp(r'^(wl|eth|en)\w*$');

  /// True when [interfaces] include a Wi-Fi or Ethernet interface with an address.
  static bool unmetered(List<NetworkInterface> interfaces) => interfaces.any(
    (i) =>
        _unmeteredName.hasMatch(i.name) &&
        i.addresses.any((a) => !a.isLoopback && !a.isLinkLocal),
  );

  @override
  Future<bool> isUnmetered() async {
    try {
      return unmetered(await _lister());
    } on SocketException {
      return false;
    }
  }

  @override
  Stream<bool> get unmeteredChanges async* {
    bool? last;
    while (true) {
      await Future<void>.delayed(interval);
      final now = await isUnmetered();
      if (now != last) {
        last = now;
        yield now;
      }
    }
  }
}

/// [NetworkMonitor] on the `connectivity_plus` plug-in: asks the OS which transport
/// the **active** (default-route) network uses (Android `ConnectivityManager`, iOS
/// `NWPathMonitor`) and listens for changes instead of polling. Unlike
/// [InterfaceNetworkMonitor] it is not fooled by a hotspot the phone is serving or
/// by a Wi-Fi without internet (Android then routes over mobile data).
///
/// Not seen by either monitor: Android's per-network "metered Wi-Fi" setting and
/// iOS Low Data Mode (`connectivity_plus` 7.x reports only the transport).
///
/// Unmetered when the active network is Wi-Fi or Ethernet and not mobile data.
/// When the answer is unclear (only VPN / other / Bluetooth) or the plug-in fails,
/// [fallback] decides.
class ConnectivityNetworkMonitor implements NetworkMonitor {
  /// Creates the monitor; [connectivity] is injectable for tests.
  ConnectivityNetworkMonitor({
    Connectivity? connectivity,
    NetworkMonitor? fallback,
  }) : _connectivity = connectivity ?? Connectivity(),
       _fallback = fallback ?? InterfaceNetworkMonitor();

  final Connectivity _connectivity;
  final NetworkMonitor _fallback;

  /// True / false when [results] settle it; null when only the fallback can tell.
  static bool? classify(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.mobile)) return false;
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return true;
    }
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return false;
    }
    return null; // VPN, other, Bluetooth or satellite alone
  }

  Future<bool> _decide(List<ConnectivityResult> results) async =>
      classify(results) ?? await _fallback.isUnmetered();

  @override
  Future<bool> isUnmetered() async {
    final List<ConnectivityResult> results;
    try {
      results = await _connectivity.checkConnectivity();
    } on PlatformException {
      return _fallback.isUnmetered();
    } on MissingPluginException {
      return _fallback.isUnmetered();
    }
    return _decide(results);
  }

  @override
  Stream<bool> get unmeteredChanges async* {
    bool? last;
    try {
      await for (final results in _connectivity.onConnectivityChanged) {
        final now = await _decide(results);
        if (now != last) {
          last = now;
          yield now;
        }
      }
    } on PlatformException {
      yield* _fallback.unmeteredChanges;
    } on MissingPluginException {
      yield* _fallback.unmeteredChanges;
    }
  }
}

/// The production monitor: [ConnectivityNetworkMonitor] (with
/// [InterfaceNetworkMonitor] as fallback) on Android and iOS, else
/// [InterfaceNetworkMonitor].
NetworkMonitor platformNetworkMonitor({bool? mobile}) {
  final isMobile = mobile ?? (Platform.isAndroid || Platform.isIOS);
  return isMobile ? ConnectivityNetworkMonitor() : InterfaceNetworkMonitor();
}
