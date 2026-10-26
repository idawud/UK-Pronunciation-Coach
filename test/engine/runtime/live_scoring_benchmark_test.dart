// Stop -> result benchmark for the Read screen's scoring path, on the Linux host,
// with the real recorder (fixture audio paced in real time), Silero VAD, the ONNX
// models and A3's scorer. Off by default (each run takes the clip's length in real
// time); see docs/handoff/perf-speed.md for how to run it and the results.
//
//   PERF_BENCH=1 flutter test test/engine/runtime/live_scoring_benchmark_test.dart
//
// Environment (all optional):
//   PERF_BENCH_CLIP     16 kHz WAV (default: the 60-word l3-013 fixture)
//   PERF_BENCH_PASSAGE  passage id read in the clip (default l3-013)
//   PERF_BENCH_MODELS   name=model.onnx[,name=...] (default light=assets/models/light-model.onnx);
//                       the vocab is the sibling *vocab.json
//   PERF_BENCH_THREADS  ONNX Runtime intra-op threads, e.g. 1,4 (default 4)
//   PERF_BENCH_MODES    whole,live (default both)
//   PERF_BENCH_STOP     tap (stop when the reading ends) or silence (A1's 2 s
//                       auto-stop) (default tap)
//   PERF_BENCH_RUNS     runs per configuration (default 3)
//   PERF_BENCH_OUT      JSON lines file to append results to
@Tags(['benchmark'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/data/content/bundled_content_repository.dart';
import 'package:uk_pronunciation_coach/engine/audio/audio.dart';
import 'package:uk_pronunciation_coach/engine/runtime/ctc_session.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_files.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_manifest.dart';
import 'package:uk_pronunciation_coach/engine/runtime/onnx_phoneme_recognizer.dart';
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

import 'helpers/fakes.dart';
import 'helpers/host_ort.dart';
import 'helpers/live_equivalence.dart';

const _defaultClip = 'test/engine/runtime/fixtures/l3-013_bf_emma.wav';

String _env(String name, String fallback) {
  final v = Platform.environment[name];
  return v == null || v.isEmpty ? fallback : v;
}

/// Process CPU time (all threads), from /proc/self/stat.
Duration processCpuTime() {
  final fields = File('/proc/self/stat').readAsStringSync().split(') ').last;
  final parts = fields.split(' ');
  // utime and stime are fields 14 and 15 of the whole line (11 and 12 here).
  final ticks = int.parse(parts[11]) + int.parse(parts[12]);
  return Duration(microseconds: ticks * 10000); // USER_HZ = 100
}

void main() {
  final ort = hostOrtLibraryPath();
  final enabled = Platform.environment['PERF_BENCH'] == '1';
  test(
    'stop -> result latency (whole clip vs live)',
    () async {
      final clipPath = _env('PERF_BENCH_CLIP', _defaultClip);
      final passageId = _env('PERF_BENCH_PASSAGE', 'l3-013');
      final models = {
        for (final kv in _env(
          'PERF_BENCH_MODELS',
          'light=assets/models/light-model.onnx',
        ).split(','))
          kv.split('=').first: kv.split('=').last,
      };
      final threads = _env(
        'PERF_BENCH_THREADS',
        '4',
      ).split(',').map(int.parse).toList();
      final modes = _env('PERF_BENCH_MODES', 'whole,live').split(',');
      final stopMode = _env('PERF_BENCH_STOP', 'tap');
      final runs = int.parse(_env('PERF_BENCH_RUNS', '3'));
      final out = Platform.environment['PERF_BENCH_OUT'];

      final content = BundledContentRepository.withLoader(
        (path) => File(path).readAsString(),
      );
      final passage = await content.byId(passageId);
      final wav = File(clipPath).readAsBytesSync();
      final clipSeconds = (wav.length - 44) / 32000;
      final silero = File('assets/models/silero_vad.onnx').readAsBytesSync();
      const scorer = GopPronunciationScorer();
      final dir = Directory.systemTemp.createTempSync('perf_bench');
      addTearDown(() => dir.deleteSync(recursive: true));

      for (final entry in models.entries) {
        final modelPath = entry.value;
        final vocabPath = modelPath.replaceFirst(
          RegExp(r'model\.onnx$'),
          'vocab.json',
        );
        for (final t in threads) {
          final lib = ort;
          final recognizer = OnnxPhonemeRecognizer(
            root: Directory('${dir.path}/models'),
            manifest: ModelManifest.fromJson(
              File('assets/models/manifest.json').readAsStringSync(),
            ),
            light: DirectoryLightModel(ModelFiles(modelPath, vocabPath)),
            transport: InMemoryTransport(),
            network: FakeNetwork(unmetered: false),
            deviceInfo: FakeDeviceInfo(),
            opener: (p) =>
                OrtCtcModelSession.open(p, libraryPath: lib, threads: t),
          );
          final loadWatch = Stopwatch()..start();
          await recognizer.load(ModelTier.light);
          final loadMs = loadWatch.elapsedMilliseconds;
          for (final mode in modes) {
            for (var run = 0; run < runs; run++) {
              final mic = FixtureMicSource.wav(wav);
              final recorder = CoachAudioRecorder(
                mic: mic,
                permissions: FixedMicPermissions(),
                recordingsDirectory: () async => dir,
                loadVad: () async => SileroVadBackend(silero, libraryPath: ort),
              );
              await recorder.vadName;
              final live = mode == 'live'
                  ? recognizer.startLiveRecognition()
                  : null;
              final sub = live == null
                  ? null
                  : recorder.liveAudio.listen(live.add);
              final silence = Completer<void>();
              final silenceSub = recorder.silenceDetected.listen((_) {
                if (!silence.isCompleted) silence.complete();
              });
              final cpu0 = processCpuTime();
              await recorder.start();
              if (stopMode == 'silence') {
                await silence.future;
              } else {
                await Future<void>.delayed(
                  Duration(milliseconds: (clipSeconds * 1000).round()),
                );
              }
              final pending = live?.pendingAudio;
              final watch = Stopwatch()..start();
              final cpuStop = processCpuTime();
              final clip = await recorder.stop();
              await sub?.cancel();
              final segments = await recorder.speechSegments(clip);
              final posteriors = live != null
                  ? await live.finish(clip)
                  : await recognizer.recognise(clip);
              final result = scorer.score(passage, posteriors, segments);
              final latency = watch.elapsedMilliseconds;
              final cpuEnd = processCpuTime();
              await silenceSub.cancel();
              Map<String, Object?>? equivalence;
              if (live != null) {
                final whole = scorer.score(
                  passage,
                  await recognizer.recognise(clip),
                  segments,
                );
                equivalence = compareResults(whole, result).toJson();
              }
              final stats = live == null
                  ? null
                  : recognizer.lastLiveRecognition!.stats;
              final record = <String, Object?>{
                'model': entry.key,
                'threads': t,
                'mode': mode,
                'stop': stopMode,
                'run': run,
                'clipSeconds': clip.duration.inMilliseconds / 1000,
                'loadMs': loadMs,
                'stopToResultMs': latency,
                'cpuWhileRecordingMs': (cpuStop - cpu0).inMilliseconds,
                'cpuAfterStopMs': (cpuEnd - cpuStop).inMilliseconds,
                'cpuTotalMs': (cpuEnd - cpu0).inMilliseconds,
                'pendingAtStopMs': pending?.inMilliseconds,
                'overall': result.overall,
                if (stats != null) ...{
                  'backgroundChunks': stats.backgroundChunks,
                  'backgroundSeconds': stats.backgroundSamples / 16000,
                  'tailSeconds': stats.tailSamples / 16000,
                  'tailFilled': stats.tailFilled,
                  'fallback': stats.fallbackReason,
                },
                'equivalence': ?equivalence,
                'load': File('/proc/loadavg').readAsStringSync().split(' ')[0],
              };
              // ignore: avoid_print
              print(jsonEncode(record));
              if (out != null) {
                File(out).writeAsStringSync(
                  '${jsonEncode(record)}\n',
                  mode: FileMode.append,
                );
              }
              await recorder.discard(clip);
              await recorder.dispose();
              // Let the machine settle between runs.
              await Future<void>.delayed(
                Duration(milliseconds: math.min(2000, latency)),
              );
            }
          }
          await recognizer.dispose();
        }
      }
    },
    skip: !enabled
        ? 'Set PERF_BENCH=1 to run the stop -> result benchmark'
        : ort == null
        ? 'No host ONNX Runtime library'
        : false,
    timeout: const Timeout(Duration(hours: 3)),
  );
}
