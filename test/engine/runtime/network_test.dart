import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/engine/runtime/network.dart';

class _CountingOverrides extends HttpOverrides {
  int created = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    created++;
    return super.createHttpClient(context);
  }
}

void main() {
  test('HttpModelTransport builds no HttpClient until a request is made', () async {
    // A port that nothing listens on: bound to learn a free one, then released,
    // so the request fails fast and deterministically on any machine.
    final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close(force: true);

    final spy = _CountingOverrides();
    await HttpOverrides.runZoned(() async {
      final t = HttpModelTransport();
      expect(spy.created, 0, reason: 'no client before the first request');
      // A failing request still has to create the client.
      await expectLater(
        t.get(
          Uri.parse('http://${InternetAddress.loopbackIPv4.address}:$port/x'),
        ),
        throwsA(isA<SocketException>()),
      );
      expect(spy.created, 1, reason: 'exactly one client, built on demand');
    }, createHttpClient: spy.createHttpClient);
  });

  test('HttpModelTransport uses an injected client without creating one', () {
    final spy = _CountingOverrides();
    HttpOverrides.runZoned(() {
      HttpModelTransport(client: null);
      expect(spy.created, 0);
    }, createHttpClient: spy.createHttpClient);
  });

  group('HttpModelTransport (loopback server, no network)', () {
    late HttpServer server;
    HttpOverrides? saved;
    final body = List<int>.generate(1000, (i) => i & 0xff);

    setUp(() async {
      // flutter_test's binding fakes every HttpClient (status 400); this group
      // talks to a real loopback server instead.
      saved = HttpOverrides.current;
      HttpOverrides.global = null;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final res = req.response;
        if (req.uri.path == '/missing') {
          res.statusCode = HttpStatus.notFound;
        } else {
          final range = req.headers.value(HttpHeaders.rangeHeader);
          final norange = req.uri.path == '/norange';
          if (range != null && !norange) {
            final from = int.parse(
              RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!,
            );
            res
              ..statusCode = HttpStatus.partialContent
              ..contentLength = body.length - from
              ..add(body.sublist(from));
          } else {
            res
              ..contentLength = body.length
              ..add(body);
          }
        }
        await res.close();
      });
    });
    tearDown(() async {
      HttpOverrides.global = saved;
      await server.close(force: true);
    });

    Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

    test('full, ranged and ignored-range requests', () async {
      final t = HttpModelTransport();
      final full = await t.get(url('/model.onnx'));
      expect(full.resumed, isFalse);
      expect(full.contentLength, 1000);
      expect((await full.body.expand((c) => c).toList()), body);

      final part = await t.get(url('/model.onnx'), offset: 600);
      expect(part.resumed, isTrue);
      expect(part.contentLength, 400);
      expect((await part.body.expand((c) => c).toList()), body.sublist(600));

      final ignored = await t.get(url('/norange'), offset: 600);
      expect(ignored.resumed, isFalse);
      await ignored.body.drain<void>();
    });

    test('HTTP errors throw HttpException', () async {
      await expectLater(
        HttpModelTransport().get(url('/missing')),
        throwsA(isA<HttpException>()),
      );
    });
  });

  test('AlwaysUnmetered', () async {
    const n = AlwaysUnmetered();
    expect(await n.isUnmetered(), isTrue);
    expect(await n.unmeteredChanges.isEmpty, isTrue);
  });

  group('InterfaceNetworkMonitor', () {
    NetworkInterface nic(String name, List<String> addresses) =>
        _Nic(name, [for (final a in addresses) _Addr(InternetAddress(a))]);

    test('Wi-Fi and Ethernet with an address are unmetered', () {
      bool u(List<NetworkInterface> l) => InterfaceNetworkMonitor.unmetered(l);
      expect(
        u([
          nic('wlan0', ['192.168.1.20']),
        ]),
        isTrue,
      ); // Android
      expect(
        u([
          nic('en0', ['fd00::1']),
        ]),
        isTrue,
      ); // iOS
      expect(
        u([
          nic('eth0', ['10.0.0.2']),
        ]),
        isTrue,
      );
      expect(
        u([
          nic('wlp2s0', ['10.0.0.2']),
        ]),
        isTrue,
      ); // Linux
      expect(
        u([
          nic('rmnet_data0', ['10.1.1.1']),
        ]),
        isFalse,
      ); // cellular
      expect(
        u([
          nic('pdp_ip0', ['10.1.1.1']),
        ]),
        isFalse,
      ); // iOS cellular
      expect(
        u([
          nic('tun0', ['10.8.0.1']),
        ]),
        isFalse,
      ); // VPN
      expect(
        u([
          nic('lo', ['127.0.0.1']),
        ]),
        isFalse,
      );
      expect(
        u([
          nic('wlan0', ['fe80::1']),
        ]),
        isFalse,
        reason: 'link-local',
      );
      expect(u([nic('wlan0', [])]), isFalse);
      expect(u([]), isFalse);
    });

    test('reads the OS interfaces', () async {
      final m = InterfaceNetworkMonitor();
      expect(await m.isUnmetered(), isA<bool>());
    });

    test('lister errors mean metered; changes are polled', () async {
      var calls = 0;
      final answers = <List<NetworkInterface>>[
        [
          nic('rmnet0', ['10.1.1.1']),
        ],
        [
          nic('rmnet0', ['10.1.1.1']),
        ],
        [
          nic('wlan0', ['192.168.1.2']),
        ],
        [],
      ];
      final m = InterfaceNetworkMonitor(
        lister: () async => answers[calls++ % answers.length],
        interval: const Duration(milliseconds: 1),
      );
      expect(await m.unmeteredChanges.take(3).toList(), [false, true, false]);
      final failing = InterfaceNetworkMonitor(
        lister: () async => throw const SocketException('no interfaces'),
      );
      expect(await failing.isUnmetered(), isFalse);
    });
  });

  group('ConnectivityNetworkMonitor', () {
    const wifi = ConnectivityResult.wifi,
        eth = ConnectivityResult.ethernet,
        mobile = ConnectivityResult.mobile,
        vpn = ConnectivityResult.vpn,
        other = ConnectivityResult.other,
        none = ConnectivityResult.none;

    test('classify', () {
      bool? c(List<ConnectivityResult> r) =>
          ConnectivityNetworkMonitor.classify(r);
      expect(c([wifi]), isTrue);
      expect(c([eth]), isTrue);
      expect(c([wifi, vpn]), isTrue);
      expect(c([mobile]), isFalse);
      expect(c([vpn, mobile]), isFalse);
      expect(c([wifi, mobile]), isFalse); // be safe: data may be charged
      expect(c([mobile, ConnectivityResult.satellite]), isFalse);
      expect(c([none]), isFalse);
      expect(c([]), isFalse);
      expect(c([vpn]), isNull);
      expect(c([other]), isNull);
      expect(c([ConnectivityResult.bluetooth]), isNull);
    });

    test('answers from the plug-in, else from the fallback', () async {
      final conn = _FakeConnectivity([wifi]);
      final fallback = _FixedNetwork(false);
      final m = ConnectivityNetworkMonitor(
        connectivity: conn,
        fallback: fallback,
      );
      expect(await m.isUnmetered(), isTrue);
      conn.now = [mobile];
      expect(await m.isUnmetered(), isFalse);
      conn.now = [vpn];
      expect(await m.isUnmetered(), isFalse); // fallback
      fallback.value = true;
      expect(await m.isUnmetered(), isTrue);
    });

    test('plug-in errors use the fallback', () async {
      for (final error in [
        PlatformException(code: 'x'),
        MissingPluginException(),
      ]) {
        final m = ConnectivityNetworkMonitor(
          connectivity: _FakeConnectivity([wifi], error: error),
          fallback: _FixedNetwork(true, changes: [true, false]),
        );
        expect(await m.isUnmetered(), isTrue);
        expect(await m.unmeteredChanges.toList(), [true, false]);
      }
    });

    test('changes are mapped and de-duplicated', () async {
      final conn = _FakeConnectivity([none]);
      final m = ConnectivityNetworkMonitor(
        connectivity: conn,
        fallback: _FixedNetwork(true),
      );
      final got = m.unmeteredChanges.toList();
      conn.changes
        ..add([mobile])
        ..add([mobile, vpn])
        ..add([wifi])
        ..add([other]) // fallback says true: no change
        ..add([none]);
      await conn.changes.close();
      expect(await got, [false, true, false]);
    });

    test('platformNetworkMonitor', () {
      expect(
        platformNetworkMonitor(mobile: true),
        isA<ConnectivityNetworkMonitor>(),
      );
      expect(
        platformNetworkMonitor(mobile: false),
        isA<InterfaceNetworkMonitor>(),
      );
      expect(platformNetworkMonitor(), isA<InterfaceNetworkMonitor>());
    });
  });
}

class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this.now, {this.error});

  List<ConnectivityResult> now;
  final Object? error;
  final changes = StreamController<List<ConnectivityResult>>();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    if (error != null) throw error!;
    return now;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      error != null ? Stream.error(error!) : changes.stream;
}

class _FixedNetwork implements NetworkMonitor {
  _FixedNetwork(this.value, {this.changes = const []});

  bool value;
  final List<bool> changes;

  @override
  Future<bool> isUnmetered() async => value;

  @override
  Stream<bool> get unmeteredChanges => Stream.fromIterable(changes);
}

class _Nic implements NetworkInterface {
  _Nic(this.name, this.addresses);

  @override
  final String name;

  @override
  final List<InterfaceAddress> addresses;

  @override
  int get index => 0;
}

class _Addr implements InterfaceAddress {
  _Addr(this._a);

  final InternetAddress _a;

  @override
  bool get isLoopback => _a.isLoopback;

  @override
  bool get isLinkLocal => _a.isLinkLocal;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
