import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

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

/// [NetworkMonitor] on the `connectivity_plus` plug-in: Wi-Fi or Ethernet counts as
/// unmetered; mobile data, VPN-only, Bluetooth and none do not.
class ConnectivityNetworkMonitor implements NetworkMonitor {
  /// Creates the monitor; [connectivity] is injectable for tests.
  ConnectivityNetworkMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// True when [results] include Wi-Fi or Ethernet.
  static bool unmetered(List<ConnectivityResult> results) =>
      results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet);

  @override
  Future<bool> isUnmetered() async =>
      unmetered(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get unmeteredChanges =>
      _connectivity.onConnectivityChanged.map(unmetered);
}
