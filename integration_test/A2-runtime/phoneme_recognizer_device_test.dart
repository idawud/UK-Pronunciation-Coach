// On-device tests for A2: the plug-in's native ONNX Runtime, the background
// isolate and the download path, with an embedded tiny model and synthetic audio.
// Never touches the network or the microphone.
//
//   flutter test integration_test/A2-runtime -d <device>
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/runtime/audio_input.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_files.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_manifest.dart';
import 'package:uk_pronunciation_coach/engine/runtime/network.dart';
import 'package:uk_pronunciation_coach/engine/runtime/onnx_phoneme_recognizer.dart';
import 'package:uk_pronunciation_coach/engine/runtime/tier_advisor.dart';

import '../../test/contracts/phoneme_recognizer_contract.dart';
import 'tiny_model_data.dart';

/// Serves in-memory files; resumes from offsets.
class _MemoryTransport implements ModelTransport {
  final files = <String, Uint8List>{};

  @override
  Future<ModelResponse> get(Uri url, {int offset = 0}) async {
    final bytes = files[url.toString()];
    if (bytes == null) throw HttpException('HTTP 404', uri: url);
    return ModelResponse(
      body: Stream.fromIterable([
        for (var i = offset; i < bytes.length; i += 4096)
          bytes.sublist(i, math.min(i + 4096, bytes.length)),
      ]),
      resumed: offset > 0,
      contentLength: bytes.length - offset,
    );
  }
}

class _Device implements DeviceInfoSource {
  @override
  Future<DeviceSnapshot> read() => PluginDeviceInfoSource().read();
}

// Async so the files exist before the contract group is declared: the shared
// suite takes the clip as a value at declaration time.
Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final base = await getTemporaryDirectory();
  final dir = await Directory('${base.path}/a2_device_test')
      .create(recursive: true);
  final tiny = ModelFiles(
    '${dir.path}/tiny.onnx',
    '${dir.path}/tiny_vocab.json',
  );
  File(tiny.modelPath).writeAsBytesSync(base64Decode(tinyModelBase64));
  File(tiny.vocabPath).writeAsStringSync(tinyVocabJson);
  final samples = Float32List.fromList([
    for (var i = 0; i < 3 * modelSampleRate; i++) 0.3 * math.sin(i * 0.07),
  ]);
  final wav = File('${dir.path}/clip.wav')
    ..writeAsBytesSync(encodePcm16Wav(samples));
  final clip = AudioClip(path: wav.path, duration: const Duration(seconds: 3));

  tearDownAll(() => dir.delete(recursive: true));

  var n = 0;
  Future<PhonemeRecognizer> make() async {
    final transport = _MemoryTransport();
    final model = File(tiny.modelPath).readAsBytesSync();
    final vocab = File(tiny.vocabPath).readAsBytesSync();
    ModelFileEntry entry(String name, Uint8List bytes) => ModelFileEntry(
      name: name,
      tier: ModelTier.full,
      url: 'https://models.test/$name',
      sha256: sha256.convert(bytes).toString(),
      size: bytes.length,
    );
    final m = entry('full/model.onnx', model);
    final v = entry('full/vocab.json', vocab);
    transport.files[m.url] = model;
    transport.files[v.url] = vocab;
    return OnnxPhonemeRecognizer(
      root: Directory('${dir.path}/root${n++}'),
      manifest: ModelManifest([m, v]),
      light: DirectoryLightModel(tiny),
      transport: transport,
      network: const AlwaysUnmetered(),
      deviceInfo: _Device(),
    );
  }

  group('tiny model on the native runtime', () {
    runPhonemeRecognizerContract(() => make(), clip: clip);
  });

  testWidgets('bundled light model, when this build has one', (tester) async {
    final r = await OnnxPhonemeRecognizer.create();
    addTearDown(r.dispose);
    if (!await r.isTierAvailable(ModelTier.light)) {
      markTestSkipped('no light model bundled yet (A4)');
      return;
    }
    await r.load(ModelTier.light);
    final p = await r.recognise(clip);
    expect(p.frames.length, closeTo(150, 3));
    expect(ModelTier.values, contains(await r.recommendedTier()));
  });
}
