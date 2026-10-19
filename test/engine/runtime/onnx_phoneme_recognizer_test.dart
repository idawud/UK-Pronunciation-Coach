import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/runtime/ctc_session.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_files.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_manifest.dart';
import 'package:uk_pronunciation_coach/engine/runtime/onnx_phoneme_recognizer.dart';
import 'package:uk_pronunciation_coach/engine/runtime/tier_advisor.dart';

import '../../contracts/phoneme_recognizer_contract.dart';
import 'helpers/fakes.dart';
import 'helpers/host_ort.dart';

/// Pure-Dart stand-in for hosts without the plug-in's ONNX Runtime library.
class _DartSession implements CtcModelSession {
  @override
  CtcLogits run(Float32List waveform) {
    final frames = (waveform.length - 400) ~/ 320 + 1;
    final r = math.Random(frames);
    return CtcLogits(
      Float32List.fromList([
        for (var i = 0; i < frames * 8; i++) r.nextDouble() * 4,
      ]),
      frames,
      8,
    );
  }

  @override
  Future<void> close() async {}
}

CtcModelSession _dartOpener(String path) => _DartSession();

final CtcSessionOpener _opener = hostOrtLibraryPath() != null
    ? hostOpener
    : _dartOpener;

const clip = AudioClip(path: cleanWav, duration: Duration(milliseconds: 3211));

void main() {
  late Directory tmp;
  late InMemoryTransport transport;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('a2_rec');
    transport = InMemoryTransport(chunkSize: 2048);
  });
  tearDown(() => tmp.delete(recursive: true));

  OnnxPhonemeRecognizer make({
    LightModelSource light = tinyLight,
    ModelManifest? manifest,
    DeviceInfoSource? device,
    FakeNetwork? network,
  }) => OnnxPhonemeRecognizer(
    root: tmp,
    manifest: manifest ?? tinyFullManifest(transport),
    light: light,
    transport: transport,
    network: network ?? FakeNetwork(),
    deviceInfo: device ?? FakeDeviceInfo(),
    opener: _opener,
  );

  group('contract', () {
    runPhonemeRecognizerContract(() async => make(), clip: clip);
  });

  test('tiny model gives one frame per 20 ms with the vocab mapped', () async {
    final r = make();
    addTearDown(r.dispose);
    await r.load(ModelTier.light);
    final p = await r.recognise(clip);
    expect(p.frames, hasLength(160), reason: '(51386 - 400) ~/ 320 + 1');
    expect(p.vocab, ['<pad>', '<s>', '</s>', '<unk>', 't', 'iː', 'ð', 'ə']);
    expect(p.blankIndex, 0);
    expect(p.frameMs, 20);
    expect(r.lastInferenceTime, isNotNull);
  });

  test('rejects clips that are not 16 kHz', () async {
    final r = make();
    addTearDown(r.dispose);
    await r.load(ModelTier.light);
    await expectLater(
      r.recognise(clip.copyWith(sampleRate: 44100)),
      throwsArgumentError,
    );
  });

  test('a missing light model is unavailable and cannot load', () async {
    const missing = DirectoryLightModel(ModelFiles('/no.onnx', '/no.json'));
    final r = make(light: missing);
    addTearDown(r.dispose);
    expect(await r.isTierAvailable(ModelTier.light), isFalse);
    await expectLater(
      r.load(ModelTier.light),
      throwsA(isA<ModelNotAvailableException>()),
    );
    expect(await r.benchmarkLight(), isNull);
  });

  test('switching tiers labels posteriors with the model that ran', () async {
    final r = make();
    addTearDown(r.dispose);
    await r.downloadFullModel();
    final loadFull = r.load(ModelTier.full);
    final light = r.load(ModelTier.light);
    final full = r.load(ModelTier.full);
    await loadFull;
    await light;
    final p = r.recognise(clip); // queued behind the pending full load
    await full;
    expect((await p).tier, ModelTier.full);
    expect(r.loadedTier, ModelTier.full);
  });

  test('a finished download is found again after restart', () async {
    final first = make();
    await first.downloadFullModel();
    await first.dispose();
    final second = make();
    addTearDown(second.dispose);
    expect(await second.isTierAvailable(ModelTier.full), isTrue);
    await second.downloadFullModel();
    expect(second.downloadStatus.state, DownloadState.completed);
    expect(transport.requests, hasLength(2), reason: 'not fetched twice');
  });

  test('cancelDownload stops a download waiting for Wi-Fi', () async {
    final r = make(network: FakeNetwork(unmetered: false));
    addTearDown(r.dispose);
    final running = r.downloadFullModel();
    await waitForState(
      () => r.downloadStatus.state,
      DownloadState.waitingForWifi,
    );
    final failed = expectLater(running, throwsA(isA<ModelDownloadException>()));
    await r.cancelDownload();
    await failed;
    expect(r.downloadStatus.state, DownloadState.cancelled);
  });

  test(
    'without a listed full tier the size falls back to the dev model',
    () async {
      final r = make(manifest: ModelManifest.empty);
      addTearDown(r.dispose);
      expect(r.fullModelSizeBytes, fallbackFullModelBytes);
      expect(await r.isTierAvailable(ModelTier.full), isFalse);
      await expectLater(
        r.downloadFullModel(),
        throwsA(isA<ModelDownloadException>()),
      );
    },
  );

  test('recommendedTier benchmarks the light model when unsure', () async {
    final r = make(
      device: FakeDeviceInfo(const DeviceSnapshot(platform: 'linux')),
    );
    addTearDown(r.dispose);
    final time = await r.benchmarkLight();
    expect(time, isNotNull);
    expect(ModelTier.values, contains(await r.recommendedTier()));
    expect(
      File('${tmp.path}/tier.json').readAsStringSync(),
      contains('benchmark'),
    );
    expect(File('${tmp.path}/benchmark.wav').existsSync(), isFalse);
  });

  test('is unusable after dispose', () async {
    final r = make();
    await r.load(ModelTier.light);
    await r.dispose();
    await r.dispose();
    expect(r.loadedTier, isNull);
    expect(() => r.load(ModelTier.light), throwsStateError);
    expect(() => r.recognise(clip), throwsStateError);
    expect(r.recommendedTier, throwsStateError);
    expect(() => r.isTierAvailable(ModelTier.light), throwsStateError);
  });

  test('dispose without ever loading', () async {
    await make().dispose();
  });
}
