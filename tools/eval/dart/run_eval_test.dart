// I2-eval harness entry point. Runs the REAL engine on the desktop host:
// A2's OnnxPhonemeRecognizer (ONNX Runtime from the onnxruntime_v2 plug-in's Linux
// library) + A3's GopPronunciationScorer. It is a `flutter test` file because the
// recognizer imports Flutter services (no `dart run`); it is outside test/, so
// `flutter test` (check.sh / CI) never runs it. Use tools/eval/run_harness.sh, or:
//
//   EVAL_MANIFEST=tools/eval/evalset/manifest.tsv \
//   EVAL_PASSAGES=tools/eval/evalset/passages.json \
//   EVAL_DATA=tools/eval/data/evalset \
//   EVAL_MODEL_DIR=/path/to/full        # model.onnx + vocab.json
//   EVAL_OUT=tools/eval/work/run1 \
//   [EVAL_CACHE=tools/eval/work/posteriors] [EVAL_CONFIGS=name=cfg.json,...] \
//   flutter test tools/eval/dart/run_eval_test.dart
//
// Skips (passes with a notice) when the manifest, audio or model are missing.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/runtime/ctc_session.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_files.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_manifest.dart';
import 'package:uk_pronunciation_coach/engine/runtime/network.dart';
import 'package:uk_pronunciation_coach/engine/runtime/onnx_phoneme_recognizer.dart';
import 'package:uk_pronunciation_coach/engine/runtime/tier_advisor.dart';

import 'eval_harness.dart';
import 'host_ort.dart';

final _env = Platform.environment;

void main() {
  final manifest = _env['EVAL_MANIFEST'] ?? '';
  final passagesPath = _env['EVAL_PASSAGES'] ?? '';
  final modelDir = _env['EVAL_MODEL_DIR'] ?? '';
  final model = '$modelDir/model.onnx';
  final vocab = '$modelDir/vocab.json';
  final skip = manifest.isEmpty || !File(manifest).existsSync()
      ? 'EVAL_MANIFEST not set or missing'
      : !File(passagesPath).existsSync()
      ? 'EVAL_PASSAGES missing'
      : !File(model).existsSync() || !File(vocab).existsSync()
      ? 'model files missing in EVAL_MODEL_DIR ($modelDir)'
      : hostOrtLibraryPath() == null
      ? 'no host ONNX Runtime library'
      : false;

  test('eval harness', skip: skip, timeout: Timeout.none, () async {
    final items = parseManifest(
      File(manifest).readAsStringSync(),
      dataDir: _env['EVAL_DATA'] ?? File(manifest).parent.path,
    );
    final missing = items.where((i) => !File(i.wav).existsSync()).toList();
    if (missing.isNotEmpty) {
      markTestSkipped(
        '${missing.length} WAVs missing (first: ${missing.first.wav})',
      );
      return;
    }
    final passages = parsePassages(File(passagesPath).readAsStringSync());
    final tmp = await Directory.systemTemp.createTemp('i2_eval');
    final recognizer = OnnxPhonemeRecognizer(
      root: tmp,
      manifest: ModelManifest.empty,
      light: DirectoryLightModel(ModelFiles(model, vocab)),
      transport: HttpModelTransport(), // never used: no full-tier download
      network: AlwaysUnmetered(),
      deviceInfo: _HostDevice(),
      opener: _opener,
    );
    try {
      await recognizer.load(ModelTier.light); // the model in EVAL_MODEL_DIR
      Future<TimedPosteriors> recognise(String wav) async {
        final sw = Stopwatch()..start();
        final duration = wavDuration(File(wav).readAsBytesSync());
        final p = await recognizer.recognise(
          AudioClip(path: wav, duration: duration),
        );
        sw.stop();
        return TimedPosteriors(
          p,
          modelMs: recognizer.lastInferenceTime?.inMilliseconds,
          totalMs: sw.elapsedMilliseconds,
        );
      }

      final cacheDir = _env['EVAL_CACHE'] ?? '';
      final source = cacheDir.isEmpty
          ? recognise
          : PosteriorCache(
              Directory(cacheDir),
              '${File(model).lengthSync()}:${File(model).uri.pathSegments.last}',
            ).wrap(recognise);
      final out = await runEval(
        items: items,
        passages: passages,
        source: source,
        configs: parseConfigs(_env['EVAL_CONFIGS'] ?? ''),
        features: _env['EVAL_FEATURES'] == '1',
        log: (m) => stdout.writeln(m),
      );
      final dir = Directory(_env['EVAL_OUT'] ?? 'tools/eval/work/out');
      out.writeTo(dir);
      stdout.writeln('wrote ${dir.path}');
    } finally {
      await recognizer.dispose();
      await tmp.delete(recursive: true);
    }
  });
}

CtcModelSession _opener(String modelPath) => OrtCtcModelSession.open(
  modelPath,
  libraryPath: hostOrtLibraryPath(),
  threads: int.tryParse(Platform.environment['EVAL_THREADS'] ?? '') ?? 4,
);

class _HostDevice implements DeviceInfoSource {
  @override
  Future<DeviceSnapshot> read() async =>
      DeviceSnapshot(platform: Platform.operatingSystem);
}
