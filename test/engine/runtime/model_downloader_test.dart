import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/errors.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_downloader.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_manifest.dart';

import 'helpers/fakes.dart';

Uint8List _bytes(int n, [int seed = 1]) =>
    Uint8List.fromList([for (var i = 0; i < n; i++) (i * 31 + seed) & 0xff]);

void main() {
  late Directory tmp;
  late InMemoryTransport transport;
  late FakeNetwork network;
  late List<ModelFileEntry> files;
  final model = _bytes(100000);
  final vocab = _bytes(500, 7);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('a2_dl');
    transport = InMemoryTransport(chunkSize: 4096);
    network = FakeNetwork();
    final m = entryFor('full/model.onnx', model);
    final v = entryFor('full/vocab.json', vocab);
    transport.files[m.url] = model;
    transport.files[v.url] = vocab;
    files = [m, v];
  });
  tearDown(() => tmp.delete(recursive: true));

  FullModelDownloader make({List<ModelFileEntry>? list}) => FullModelDownloader(
    files: list ?? files,
    dir: Directory('${tmp.path}/full'),
    transport: transport,
    network: network,
    hashFile: (p) async => sha256OfFileSync(p),
  );

  test('sha256OfFileSync matches crypto on a multi-chunk file', () {
    final f = File('${tmp.path}/x')..writeAsBytesSync(_bytes(3 << 20));
    expect(sha256OfFileSync(f.path), shaOf(f.readAsBytesSync()));
  });

  test('downloads, verifies, reports progress and survives restart', () async {
    final d = make();
    await d.restore();
    expect(d.status.state, DownloadState.idle);
    expect(d.totalBytes, 100500);
    final seen = <ModelDownloadProgress>[];
    final sub = d.progress.listen(seen.add);
    await d.download();
    await pumpEventQueue();
    await sub.cancel();
    expect(d.status.state, DownloadState.completed);
    expect(d.status.fraction, 1.0);
    final states = seen.map((e) => e.state).toList();
    expect(
      states,
      containsAllInOrder([
        DownloadState.downloading,
        DownloadState.verifying,
        DownloadState.completed,
      ]),
    );
    expect(
      seen.where((e) => e.state == DownloadState.downloading).length,
      greaterThan(2),
    );
    expect(d.fileFor(files[0]).readAsBytesSync(), model);
    expect(await d.isComplete(), isTrue);

    // A fresh downloader trusts the marker; a second download is a no-op.
    final again = make();
    await again.restore();
    expect(again.status.state, DownloadState.completed);
    final before = transport.requests.length;
    await again.download();
    expect(transport.requests.length, before);
    await again.close();
    await d.close();
  });

  test('cancel keeps the partial file and the next call resumes', () async {
    final d = make();
    final cut = Completer<void>();
    transport.beforeChunk = (pos) async {
      if (pos >= 40000 && !cut.isCompleted) {
        cut.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    };
    final running = d.download();
    await cut.future;
    await d.cancel();
    await expectLater(running, throwsA(isA<ModelDownloadException>()));
    expect(d.status.state, DownloadState.cancelled);
    final partial = d.status.receivedBytes;
    expect(partial, inExclusiveRange(0, 100000));
    expect(d.bytesOnDisk(), partial);

    transport.beforeChunk = null;
    await d.download();
    expect(d.status.state, DownloadState.completed);
    expect(transport.requests.where((r) => r.$2 > 0), isNotEmpty);
    expect(d.fileFor(files[0]).readAsBytesSync(), model);
    await d.cancel(); // nothing running: no-op
    await d.close();
  });

  test('restarts a file when the server ignores Range', () async {
    final d = make();
    final part = File('${tmp.path}/full/model.onnx.part')
      ..createSync(recursive: true)
      ..writeAsBytesSync(model.sublist(0, 30000));
    transport.ignoreRange = true;
    await d.restore();
    expect(d.status.receivedBytes, 30000);
    await d.download();
    expect(d.status.state, DownloadState.completed);
    expect(d.fileFor(files[0]).readAsBytesSync(), model);
    expect(part.existsSync(), isFalse);
    await d.close();
  });

  test('a partial file larger than expected is discarded', () async {
    File('${tmp.path}/full/model.onnx.part')
      ..createSync(recursive: true)
      ..writeAsBytesSync(_bytes(120000));
    final d = make();
    await d.download();
    expect(d.fileFor(files[0]).readAsBytesSync(), model);
    await d.close();
  });

  test('a complete .part file is only verified, not fetched', () async {
    File('${tmp.path}/full/vocab.json.part')
      ..createSync(recursive: true)
      ..writeAsBytesSync(vocab);
    final d = make();
    await d.download();
    expect(transport.requests.map((r) => r.$1), isNot(contains(files[1].url)));
    await d.close();
  });

  test('checksum mismatch fails and deletes the bad file', () async {
    transport.tamper = (b) => Uint8List.fromList(b)..[10] ^= 0xff;
    final d = make();
    await expectLater(
      d.download(),
      throwsA(
        isA<ModelDownloadException>().having(
          (e) => e.message,
          'message',
          contains('Checksum'),
        ),
      ),
    );
    expect(d.status.state, DownloadState.failed);
    expect(d.status.error, contains('Checksum'));
    expect(await d.isComplete(), isFalse);
    expect(File('${tmp.path}/full/model.onnx.part').existsSync(), isFalse);

    transport.tamper = null;
    await d.download(); // retry succeeds
    expect(d.status.state, DownloadState.completed);
    await d.close();
  });

  test('HTTP errors and short bodies fail the download', () async {
    transport.files.remove(files[1].url);
    final d = make();
    await expectLater(d.download(), throwsA(isA<ModelDownloadException>()));
    expect(d.status.state, DownloadState.failed);
    expect(d.status.error, contains('404'));

    transport.files[files[1].url] = vocab.sublist(0, 100);
    await expectLater(d.download(), throwsA(isA<ModelDownloadException>()));
    expect(d.status.error, contains('got 100 of 500'));

    transport
      ..files[files[1].url] = vocab
      ..beforeChunk = (pos) => throw const SocketException('reset');
    await expectLater(d.download(), throwsA(isA<ModelDownloadException>()));
    expect(d.status.error, contains('reset'));
    await d.close();
  });

  test('an empty manifest cannot be downloaded', () async {
    final d = make(list: const []);
    await expectLater(d.download(), throwsA(isA<ModelDownloadException>()));
    expect(await d.isComplete(), isFalse);
    await d.close();
  });

  test('waits for Wi-Fi, then downloads', () async {
    network.unmetered = false;
    final d = make();
    final running = d.download();
    await waitForState(() => d.status.state, DownloadState.waitingForWifi);
    expect(d.status.isActive, isTrue);
    network.set(true);
    await running;
    expect(d.status.state, DownloadState.completed);
    await d.close();
  });

  test('requireWifi false downloads on mobile data', () async {
    network.unmetered = false;
    final d = make();
    await d.download(requireWifi: false);
    expect(d.status.state, DownloadState.completed);
    await d.close();
  });

  test('cancel while waiting for Wi-Fi', () async {
    network.unmetered = false;
    final d = make();
    final running = d.download();
    await waitForState(() => d.status.state, DownloadState.waitingForWifi);
    await d.cancel();
    await expectLater(running, throwsA(isA<ModelDownloadException>()));
    expect(d.status.state, DownloadState.cancelled);
    await d.close();
  });

  test('losing Wi-Fi pauses and resumes when it returns', () async {
    final d = make();
    var dropped = false;
    transport.beforeChunk = (pos) async {
      if (pos >= 50000 && !dropped) {
        dropped = true;
        network.set(false);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    };
    final running = d.download();
    while (d.status.state != DownloadState.waitingForWifi) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(d.status.receivedBytes, greaterThan(0));
    network.set(true);
    await running;
    expect(d.status.state, DownloadState.completed);
    expect(d.fileFor(files[0]).readAsBytesSync(), model);
    await d.close();
  });

  test('cancel straight after starting is not lost', () async {
    final d = make();
    final running = d.download();
    await d.cancel();
    await expectLater(running, throwsA(isA<ModelDownloadException>()));
    expect(d.status.state, DownloadState.cancelled);
    expect(transport.requests, isEmpty);
    await d.close();
  });

  test('concurrent calls share one download', () async {
    final d = make();
    final a = d.download();
    final b = d.download();
    await Future.wait([a, b]);
    expect(transport.requests.where((r) => r.$1 == files[0].url).length, 1);
    await d.close();
  });

  test('delete removes everything and resets to idle', () async {
    final d = make();
    await d.download();
    await d.delete();
    expect(d.status.state, DownloadState.idle);
    expect(await d.isComplete(), isFalse);
    expect(Directory('${tmp.path}/full').existsSync(), isFalse);
    await d.delete(); // nothing there: fine
    await d.close();
  });

  test('isComplete rejects a stale or corrupt marker', () async {
    final d = make();
    await d.download();
    final marker = File('${tmp.path}/full/verified.json');
    marker.writeAsStringSync('not json');
    expect(await d.isComplete(), isFalse);
    marker.writeAsStringSync('{"model.onnx": "00", "vocab.json": "00"}');
    expect(await d.isComplete(), isFalse);
    await d.restore();
    expect(d.status.state, DownloadState.idle);
    expect(d.status.receivedBytes, 100500, reason: 'finished files count');
    await d.close();
  });
}
