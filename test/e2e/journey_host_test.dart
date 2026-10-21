// Host mirror of the on-device e2e journey (integration_test/e2e/journey.dart):
// the same steps on the Linux host with the real implementations wherever they
// run off a phone:
//
// - A1's CoachAudioRecorder with the bundled Silero VAD, fed fixture audio;
// - A2's OnnxPhonemeRecognizer with the bundled light model on the host ONNX
//   Runtime (the full model is not downloaded, so Auto uses light);
// - A3's scorer and tips, C1's bundled content, C2's drift database (a file), C3's
//   practice engine.
//
// Only the platform plug-ins are fakes: the microphone (fixture audio), the
// permission prompt, the TTS voice and the notification scheduler.
//
// Needs the light model: `python3 tools/ci/fetch_models.py --tier light`. Skipped
// without it (or on a non-Linux host, which has no ONNX Runtime library here).
@Tags(['e2e'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/app.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/data/progress/drift_progress_repository.dart';
import 'package:uk_pronunciation_coach/engine/audio/audio.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_files.dart';
import 'package:uk_pronunciation_coach/engine/runtime/model_manifest.dart';
import 'package:uk_pronunciation_coach/engine/runtime/onnx_phoneme_recognizer.dart';

import '../../integration_test/e2e/journey.dart';
import '../engine/runtime/helpers/fakes.dart';
import '../engine/runtime/helpers/host_ort.dart';

const _lightModel = 'assets/models/light-model.onnx';
const _lightVocab = 'assets/models/light-vocab.json';

/// The fixture clips from test/e2e/fixtures/ (see its README).
JourneyClips hostClips() {
  Uint8List read(String name) =>
      File('test/e2e/fixtures/$name').readAsBytesSync();
  return JourneyClips(
    offScript: read('off_script.wav'),
    goodReads: {
      'l1-003': read('l1-003.wav'),
      'l1-004': read('l1-004.wav'),
      'l1-014': read('l1-014.wav'),
    },
  );
}

void main() {
  final ort = hostOrtLibraryPath();
  final skip = ort == null
      ? 'No host ONNX Runtime library (Linux only)'
      : !File(_lightModel).existsSync()
      ? 'Light model not fetched: python3 tools/ci/fetch_models.py --tier light'
      : null;

  testWidgets(
    'first run -> placement -> Read -> Results -> Fix -> level up -> '
    'Progress -> delete all data (real engine, fixture audio, no network)',
    (tester) async {
      debugUseFakesOverride = false;
      addTearDown(() => debugUseFakesOverride = true);

      final dir = Directory.systemTemp.createTempSync('i1_e2e');
      final recordings = Directory('${dir.path}/recordings')..createSync();
      final mic = JourneyMic(realTime: false);
      final transport = InMemoryTransport(); // no files: any request would fail
      late DriftProgressRepository store;
      late OnnxPhonemeRecognizer recognizer;
      late CoachAudioRecorder recorder;
      await tester.runAsync(() async {
        store = await DriftProgressRepository.open(
          file: File('${dir.path}/progress.sqlite'),
          recordingsDir: recordings,
        );
        recognizer = OnnxPhonemeRecognizer(
          root: Directory('${dir.path}/models'),
          manifest: ModelManifest.fromJson(
            File('assets/models/manifest.json').readAsStringSync(),
          ),
          light: const DirectoryLightModel(
            ModelFiles(_lightModel, _lightVocab),
          ),
          transport: transport,
          network: FakeNetwork(unmetered: false),
          deviceInfo: FakeDeviceInfo(),
          opener: hostOpener,
        );
        final silero = File('assets/models/silero_vad.onnx').readAsBytesSync();
        recorder = CoachAudioRecorder(
          mic: mic,
          permissions: FixedMicPermissions(),
          recordingsDirectory: () async => recordings,
          loadVad: () async => SileroVadBackend(silero, libraryPath: ort),
        );
        expect(await recorder.vadName, 'silero');
      });
      addTearDown(() async {
        await tester.runAsync(() async {
          await recorder.dispose();
          await recognizer.dispose();
          await store.close();
        });
        dir.deleteSync(recursive: true);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressStoreProvider.overrideWith((ref) async => store),
            recognizerStoreProvider.overrideWith((ref) async => recognizer),
            audioRecorderProvider.overrideWithValue(recorder),
            voiceServiceProvider.overrideWithValue(FakeVoiceService()),
          ],
          child: const CoachApp(),
        ),
      );

      await Journey(
        tester,
        mic: mic,
        clips: hostClips(),
        idle: () => tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        ),
      ).run();

      expect(recognizer.loadedTier?.name, 'light');
      expect(transport.requests, isEmpty, reason: 'no model download');
      // Nothing is left in the recordings folder: unsaved clips are discarded and
      // saved ones deleted (keep recordings is off), then Delete all data.
      expect(recordings.listSync(), isEmpty);
    },
    skip: skip != null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
  if (skip != null) {
    // ignore: avoid_print
    print('journey_host_test skipped: $skip');
  }
}
