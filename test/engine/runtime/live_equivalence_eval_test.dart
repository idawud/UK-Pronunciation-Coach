// Live (piecewise) vs whole-clip recognition on a folder of read passages: word
// score differences, status agreement and non-green words, per model. Off by
// default; see docs/handoff/perf-speed.md.
//
//   PERF_EQUIV_DIR=<folder of <passageId>.<anything>.wav> \
//   PERF_EQUIV_MODELS=light=assets/models/light-model.onnx,full=/path/model.onnx \
//   flutter test test/engine/runtime/live_equivalence_eval_test.dart
//
// Optional: PERF_EQUIV_MIN_CHUNK_MS, PERF_EQUIV_CONTEXT_MS (LiveChunking),
// PERF_EQUIV_PASSAGES (JSON list of passages to use instead of the bundled ones),
// PERF_EQUIV_OUT (JSON lines file).
@Tags(['benchmark'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/data/content/bundled_content_repository.dart';
import 'package:uk_pronunciation_coach/engine/audio/audio.dart';
import 'package:uk_pronunciation_coach/engine/runtime/chunk_planner.dart';
import 'package:uk_pronunciation_coach/engine/runtime/ctc_session.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_files.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_manifest.dart';
import 'package:uk_pronunciation_coach/engine/runtime/onnx_phoneme_recognizer.dart';
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

import 'helpers/fakes.dart';
import 'helpers/host_ort.dart';
import 'helpers/live_equivalence.dart';

int _argmax(List<double> row) {
  var best = 0;
  for (var i = 1; i < row.length; i++) {
    if (row[i] > row[best]) best = i;
  }
  return best;
}

void main() {
  final ort = hostOrtLibraryPath();
  final dirPath = Platform.environment['PERF_EQUIV_DIR'];
  test(
    'live vs whole-clip recognition on read passages',
    () async {
      final env = Platform.environment;
      final models = {
        for (final kv
            in (env['PERF_EQUIV_MODELS'] ??
                    'light=assets/models/light-model.onnx')
                .split(','))
          kv.split('=').first: kv.split('=').last,
      };
      final chunking = LiveChunking(
        minChunk: Duration(
          milliseconds: int.parse(env['PERF_EQUIV_MIN_CHUNK_MS'] ?? '1000'),
        ),
        context: Duration(
          milliseconds: int.parse(env['PERF_EQUIV_CONTEXT_MS'] ?? '160'),
        ),
      );
      final content = BundledContentRepository.withLoader(
        (path) => File(path).readAsString(),
      );
      final clips =
          Directory(dirPath!)
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.wav'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      // PERF_EQUIV_PASSAGES: a JSON list of passages (e.g. sentences joined into
      // long passages) that takes priority over the bundled content.
      final composite = <String, Passage>{
        if (env['PERF_EQUIV_PASSAGES'] case final path?)
          for (final p
              in jsonDecode(File(path).readAsStringSync()) as List<dynamic>)
            (p as Map<String, dynamic>)['id'] as String: Passage.fromJson(p),
      };
      final silero = File('assets/models/silero_vad.onnx').readAsBytesSync();
      const scorer = GopPronunciationScorer();
      final tmp = Directory.systemTemp.createTempSync('perf_equiv');
      addTearDown(() => tmp.deleteSync(recursive: true));
      for (final m in models.entries) {
        final lib = ort;
        final recognizer = OnnxPhonemeRecognizer(
          root: Directory('${tmp.path}/models'),
          manifest: ModelManifest.fromJson(
            File('assets/models/manifest.json').readAsStringSync(),
          ),
          light: DirectoryLightModel(
            ModelFiles(
              m.value,
              m.value.replaceFirst(RegExp(r'model\.onnx$'), 'vocab.json'),
            ),
          ),
          transport: InMemoryTransport(),
          network: FakeNetwork(unmetered: false),
          deviceInfo: FakeDeviceInfo(),
          opener: (p) =>
              OrtCtcModelSession.open(p, libraryPath: lib, threads: 4),
        )..liveChunking = chunking;
        await recognizer.load(ModelTier.light);
        var frames = 0,
            sameFrames = 0,
            words = 0,
            same = 0,
            wholeBad = 0,
            liveBad = 0,
            maxDiff = 0;
        var sumDiff = 0.0;
        for (final f in clips) {
          final name = f.uri.pathSegments.last;
          final id = name.split('.').first;
          final passage = composite[id] ?? await content.byId(id);
          final recorder = CoachAudioRecorder(
            mic: FixtureMicSource.wav(
              f.readAsBytesSync(),
              realTime: false,
              silenceAfter: false,
            ),
            permissions: FixedMicPermissions(),
            recordingsDirectory: () async => tmp,
            loadVad: () async => SileroVadBackend(silero, libraryPath: ort),
          );
          await recorder.vadName;
          final live = recognizer.startLiveRecognition();
          final sub = recorder.liveAudio.listen(live.add);
          await recorder.start();
          await Future<void>.delayed(const Duration(milliseconds: 500));
          final clip = await recorder.stop();
          await sub.cancel();
          final segments = await recorder.speechSegments(clip);
          final livePost = await live.finish(clip);
          final wholePost = await recognizer.recognise(clip);
          frames += wholePost.frames.length;
          for (var f = 0; f < wholePost.frames.length; f++) {
            if (_argmax(wholePost.frames[f]) == _argmax(livePost.frames[f])) {
              sameFrames++;
            }
          }
          final c = compareResults(
            scorer.score(passage, wholePost, segments),
            scorer.score(passage, livePost, segments),
          );
          words += c.words;
          same += (c.statusAgreement * c.words).round();
          sumDiff += c.meanWordDiff * c.words;
          wholeBad += c.wholeNotGood;
          liveBad += c.liveNotGood;
          if (c.maxWordDiff > maxDiff) maxDiff = c.maxWordDiff;
          final record = {
            'model': m.key,
            'clip': name,
            'pieces':
                recognizer.lastLiveRecognition!.stats.backgroundChunks + 1,
            ...c.toJson(),
          };
          // ignore: avoid_print
          print(jsonEncode(record));
          final out = env['PERF_EQUIV_OUT'];
          if (out != null) {
            File(out).writeAsStringSync(
              '${jsonEncode(record)}\n',
              mode: FileMode.append,
            );
          }
          await recorder.discard(clip);
          await recorder.dispose();
        }
        // ignore: avoid_print
        print(
          jsonEncode({
            'model': m.key,
            'summary': true,
            'minChunkMs': chunking.minChunk.inMilliseconds,
            'contextMs': chunking.context.inMilliseconds,
            'clips': clips.length,
            'frameAgreement': sameFrames / frames,
            'words': words,
            'statusAgreement': same / words,
            'meanWordDiff': sumDiff / words,
            'maxWordDiff': maxDiff,
            'wholeNotGood': wholeBad / words,
            'liveNotGood': liveBad / words,
          }),
        );
        await recognizer.dispose();
      }
    },
    skip: dirPath == null
        ? 'Set PERF_EQUIV_DIR to a folder of read passages'
        : ort == null
        ? 'No host ONNX Runtime library'
        : false,
    timeout: const Timeout(Duration(hours: 2)),
  );
}
