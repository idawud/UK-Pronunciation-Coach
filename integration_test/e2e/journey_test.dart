// On-device e2e journey (I1-integration): the whole app with the real
// implementations on an emulator / simulator: A1's recorder (bundled Silero VAD)
// fed fixture audio instead of the microphone, A2's recognizer on the bundled
// light model, A3, C1, C2 (a fresh database file), C3, C4's system voice and U4's
// reminder scheduler. integration.yml turns aeroplane mode on first; the journey
// also fails if the app opens any HTTP client or socket.
//
//   flutter test integration_test/e2e -d <device>
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uk_pronunciation_coach/app.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/data/progress/drift_progress_repository.dart';
import 'package:uk_pronunciation_coach/engine/audio/audio.dart';

import 'fixture_clips.dart';
import 'journey.dart';

Uint8List _clip(String name) => base64Decode(fixtureClipsBase64[name]!);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first run -> placement -> Read -> Results -> Fix -> level up -> '
      'Progress -> delete all data (fixture audio, network off)', (
    tester,
  ) async {
    final dir = await Directory.systemTemp.createTemp('i1_e2e');
    final store = await DriftProgressRepository.open(
      file: File('${dir.path}/progress.sqlite'),
      recordingsDir: await defaultRecordingsDirectory(),
    );
    final mic = JourneyMic();
    final recorder = CoachAudioRecorder(
      mic: mic,
      permissions: FixedMicPermissions(),
    );
    expect(await recorder.vadName, 'silero', reason: 'Silero is bundled');
    addTearDown(() async {
      await recorder.dispose();
      await store.close();
      await dir.delete(recursive: true);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressStoreProvider.overrideWith((ref) async => store),
          audioRecorderProvider.overrideWithValue(recorder),
        ],
        child: const CoachApp(),
      ),
    );

    await Journey(
      tester,
      mic: mic,
      clips: JourneyClips(
        offScript: _clip('off_script.wav'),
        goodReads: {
          'l1-003': _clip('l1-003.wav'),
          'l1-004': _clip('l1-004.wav'),
          'l1-014': _clip('l1-014.wav'),
        },
      ),
      idle: () => Future<void>.delayed(const Duration(milliseconds: 20)),
      timeout: const Duration(minutes: 3),
    ).run();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
