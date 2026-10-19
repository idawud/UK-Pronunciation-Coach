// Runs the real development model (facebook/wav2vec2-lv-60-espeak-cv-ft, ONNX uint8
// export from Hugging Face onnx-community) when it is in the git-ignored cache:
//
//   .model-cache/dev/model_quantized.onnx + .model-cache/dev/vocab.json
//   (or set A2_DEV_MODEL_DIR; see docs/handoff/A2-runtime.md for the download)
//
// Skipped when the files are absent (CI). Prints the timing benchmark for a 20 s clip.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/runtime/audio_input.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_files.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_manifest.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_vocab.dart';
import 'package:uk_pronunciation_coach/engine/runtime/onnx_phoneme_recognizer.dart';

import '../../contracts/phoneme_recognizer_contract.dart';
import 'helpers/fakes.dart';
import 'helpers/host_ort.dart';

final _dir = Platform.environment['A2_DEV_MODEL_DIR'] ?? '.model-cache/dev';
final _model = '$_dir/model_quantized.onnx';
final _vocab = '$_dir/vocab.json';
final _skip = hostOrtLibraryPath() == null
    ? 'no host ONNX Runtime'
    : !File(_model).existsSync() || !File(_vocab).existsSync()
    ? 'dev model not downloaded ($_model)'
    : false;

void main() {
  late Directory tmp;
  setUpAll(() async => tmp = await Directory.systemTemp.createTemp('a2_dev'));
  tearDownAll(() => tmp.delete(recursive: true));

  final light = DirectoryLightModel(ModelFiles(_model, _vocab));
  OnnxPhonemeRecognizer make() => OnnxPhonemeRecognizer(
    root: Directory('${tmp.path}/${math.Random().nextInt(1 << 30)}'),
    manifest: ModelManifest.empty,
    light: light,
    transport: InMemoryTransport(),
    network: FakeNetwork(),
    deviceInfo: FakeDeviceInfo(),
    opener: hostOpener,
  );
  const clip = AudioClip(
    path: cleanWav,
    duration: Duration(milliseconds: 3211),
  );

  group('dev model', skip: _skip, () {
    runPhonemeRecognizerContract(
      () async => make(),
      clip: clip,
      checkDownload: false,
    );

    test('vocab: 392 symbols, <pad> blank at 0, 20 ms frames', () async {
      final vocab = ModelVocab.fromJson(File(_vocab).readAsStringSync());
      expect(vocab.length, 392);
      expect(vocab.blankIndex, 0);
      expect(vocab.symbols.take(4), ['<pad>', '<s>', '</s>', '<unk>']);

      final r = make();
      addTearDown(r.dispose);
      await r.load(ModelTier.light);
      final p = await r.recognise(clip);
      expect(p.vocab, vocab.symbols);
      expect(p.frames, hasLength(160), reason: '51386 samples -> 160 frames');
      expect(p.frames.first, hasLength(392));
      final heard = greedyDecode(p.frames, vocab);
      // ignore: avoid_print
      print(
        'clean_read.wav ("On Thursday we walked by the river."): '
        '${heard.join(' ')}',
      );
      // eSpeak speech, so the model should hear the key sounds of "Thursday",
      // "walked" and "river".
      expect(heard, containsAll(['θ', 'w', 'ɹ', 'v']));
    });

    test('benchmark: 20 s clip', () async {
      final speech = decodePcm16Wav(File(cleanWav).readAsBytesSync());
      const seconds = 20;
      final samples = Float32List(seconds * modelSampleRate);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = speech[i % speech.length];
      }
      final wav = File('${tmp.path}/bench20.wav')
        ..writeAsBytesSync(encodePcm16Wav(samples));
      final clip20 = AudioClip(
        path: wav.path,
        duration: const Duration(seconds: seconds),
      );

      final r = make();
      addTearDown(r.dispose);
      final load = Stopwatch()..start();
      await r.load(ModelTier.light);
      load.stop();
      await r.recognise(clip); // warm-up
      final runs = <int>[];
      final model = <int>[];
      late PhonemePosteriors p;
      for (var i = 0; i < 3; i++) {
        final w = Stopwatch()..start();
        p = await r.recognise(clip20);
        w.stop();
        runs.add(w.elapsedMilliseconds);
        model.add(r.lastInferenceTime!.inMilliseconds);
      }
      runs.sort();
      model.sort();
      expect(p.frames, hasLength(999));
      // ignore: avoid_print
      print(
        'A2 benchmark (${Platform.numberOfProcessors} CPUs, 4 ORT threads, '
        'wav2vec2-lv-60-espeak-cv-ft uint8): load ${load.elapsedMilliseconds} ms; '
        '20 s clip end-to-end ${runs.join(' / ')} ms '
        '(median ${runs[1]} ms, RTF ${(runs[1] / 20000).toStringAsFixed(3)}); '
        'model alone ${model.join(' / ')} ms',
      );
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
