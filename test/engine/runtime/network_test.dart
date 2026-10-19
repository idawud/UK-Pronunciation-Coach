import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uk_pronunciation_coach/engine/runtime/network.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
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

  group('ConnectivityNetworkMonitor', () {
    test('Wi-Fi and Ethernet are unmetered; mobile and none are not', () {
      bool u(List<ConnectivityResult> r) =>
          ConnectivityNetworkMonitor.unmetered(r);
      expect(u([ConnectivityResult.wifi]), isTrue);
      expect(
        u([ConnectivityResult.mobile, ConnectivityResult.ethernet]),
        isTrue,
      );
      expect(u([ConnectivityResult.mobile]), isFalse);
      expect(u([ConnectivityResult.vpn]), isFalse);
      expect(u([ConnectivityResult.none]), isFalse);
    });

    test('reads and watches the plug-in', () async {
      final c = _MockConnectivity();
      final changes = StreamController<List<ConnectivityResult>>();
      when(c.checkConnectivity)
          .thenAnswer((_) async => [ConnectivityResult.mobile]);
      when(() => c.onConnectivityChanged).thenAnswer((_) => changes.stream);
      final m = ConnectivityNetworkMonitor(connectivity: c);
      expect(await m.isUnmetered(), isFalse);
      final seen = m.unmeteredChanges.take(2).toList();
      changes
        ..add([ConnectivityResult.wifi])
        ..add([ConnectivityResult.none]);
      expect(await seen, [true, false]);
      await changes.close();
    });
  });
}
