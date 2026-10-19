import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_files.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_manifest.dart';
import 'package:uk_pronunciation_coach/engine/runtime/network.dart';
import 'package:uk_pronunciation_coach/engine/runtime/tier_advisor.dart';

/// Fixture folder for this test suite.
const fixtures = 'test/engine/runtime/fixtures';

/// Tiny model files (see fixtures/make_tiny_model.py).
const tinyModel = '$fixtures/tiny_ctc.onnx';
const tinyMaskModel = '$fixtures/tiny_ctc_mask.onnx';
const tinyVocab = '$fixtures/tiny_vocab.json';

/// Light source using the tiny model.
const tinyLight = DirectoryLightModel(ModelFiles(tinyModel, tinyVocab));

/// The shared clean speech fixture (16 kHz mono).
const cleanWav = 'test/fixtures/audio/clean_read.wav';

/// Hex SHA-256 of [bytes].
String shaOf(List<int> bytes) => sha256.convert(bytes).toString();

/// A manifest entry serving [bytes] at `https://models.test/<name>`.
ModelFileEntry entryFor(
  String name,
  List<int> bytes, {
  ModelTier tier = ModelTier.full,
  bool bundle = false,
}) => ModelFileEntry(
  name: name,
  tier: tier,
  url: 'https://models.test/$name',
  sha256: shaOf(bytes),
  size: bytes.length,
  bundle: bundle,
);

/// Full-tier manifest serving the tiny model; also registers it in [transport].
ModelManifest tinyFullManifest(InMemoryTransport transport) {
  final model = File(tinyMaskModel).readAsBytesSync();
  final vocab = File(tinyVocab).readAsBytesSync();
  final m = entryFor('full/model.onnx', model);
  final v = entryFor('full/vocab.json', vocab);
  transport.files[m.url] = model;
  transport.files[v.url] = vocab;
  return ModelManifest([m, v]);
}

/// In-memory [ModelTransport]: serves [files] by URL in [chunkSize] pieces, honours
/// offsets unless [ignoreRange], and records every request.
class InMemoryTransport implements ModelTransport {
  /// Creates the transport.
  InMemoryTransport({this.chunkSize = 1024, this.ignoreRange = false});

  /// Bytes by URL.
  final files = <String, Uint8List>{};

  /// Chunk size of the body stream.
  int chunkSize;

  /// Pretend the server does not support `Range`.
  bool ignoreRange;

  /// Requests made, as (url, offset).
  final requests = <(String, int)>[];

  /// Called before each chunk is emitted with the byte position; may throw or await.
  FutureOr<void> Function(int position)? beforeChunk;

  /// Bytes to serve instead of the real ones (corruption tests).
  Uint8List Function(Uint8List bytes)? tamper;

  @override
  Future<ModelResponse> get(Uri url, {int offset = 0}) async {
    requests.add((url.toString(), offset));
    final bytes = files[url.toString()];
    if (bytes == null) throw HttpException('HTTP 404', uri: url);
    final served = tamper?.call(bytes) ?? bytes;
    final start = ignoreRange ? 0 : offset;
    return ModelResponse(
      body: _chunks(served, start),
      resumed: !ignoreRange && offset > 0,
      contentLength: served.length - start,
    );
  }

  Stream<List<int>> _chunks(Uint8List bytes, int start) async* {
    for (var i = start; i < bytes.length; i += chunkSize) {
      await beforeChunk?.call(i);
      yield bytes.sublist(
        i,
        i + chunkSize > bytes.length ? bytes.length : i + chunkSize,
      );
    }
  }
}

/// Controllable [NetworkMonitor].
class FakeNetwork implements NetworkMonitor {
  /// Creates the monitor.
  FakeNetwork({this.unmetered = true});

  /// Current answer.
  bool unmetered;

  final _changes = StreamController<bool>.broadcast();

  /// Changes the answer and notifies listeners.
  void set(bool value) {
    unmetered = value;
    _changes.add(value);
  }

  @override
  Future<bool> isUnmetered() async => unmetered;

  @override
  Stream<bool> get unmeteredChanges => _changes.stream;
}

/// Fixed [DeviceInfoSource].
class FakeDeviceInfo implements DeviceInfoSource {
  /// Creates the source.
  FakeDeviceInfo([
    this.snapshot = const DeviceSnapshot(
      platform: 'android',
      ramMb: 6000,
      androidSdk: 33,
    ),
  ]);

  /// The answer.
  DeviceSnapshot snapshot;

  /// Calls to [read].
  int reads = 0;

  @override
  Future<DeviceSnapshot> read() async {
    reads++;
    return snapshot;
  }
}

/// Waits (real time, up to [timeout]) until [state] reads [want]. File I/O in the
/// code under test is truly asynchronous, so `pumpEventQueue` alone is not enough.
Future<void> waitForState(
  DownloadState Function() state,
  DownloadState want, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (state() != want) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('state is ${state()}, wanted $want');
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}
