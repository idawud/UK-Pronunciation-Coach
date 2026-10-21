import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/read/read_state.dart';
import 'package:uk_pronunciation_coach/ui/read/scoring_controller.dart';

import 'read_test_helpers.dart';

void main() {
  late ReadHarness h;
  late ProviderContainer container;
  late ReadArgs args;

  Future<void> until(bool Function() condition, {String? reason}) async {
    for (var i = 0; i < 500; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    fail('Timed out waiting: ${reason ?? 'condition'}');
  }

  ReadState state() => container.read(scoringControllerProvider(args));
  ScoringController controller() =>
      container.read(scoringControllerProvider(args).notifier);

  Future<ScoringController> open(
    ReadArgs a, {
    ReadHarness? harness,
    bool waitIdle = true,
  }) async {
    h = harness ?? ReadHarness();
    args = a;
    container = ProviderContainer(overrides: h.overrides);
    addTearDown(container.dispose);
    container.listen(scoringControllerProvider(a), (_, _) {});
    if (waitIdle) {
      await until(() => state().phase is! ReadLoading, reason: 'loaded');
    }
    return controller();
  }

  Future<ReadPhase> recordAndStop(ScoringController c) async {
    await c.startRecording();
    expect(state().phase, isA<ReadRecording>());
    await c.stopRecording();
    return state().phase;
  }

  final passageArgs = ReadArgs(passageId: riverPassage.id);

  group('loading', () {
    test('shows the passage with its number and the saved text size', () async {
      await open(
        passageArgs,
        harness: ReadHarness(profile: const UserProfile(textScale: 1.3)),
      );
      final s = state();
      expect(s.phase, isA<ReadIdle>());
      expect(s.content!.target, riverPassage);
      expect(s.content!.passageNumber, 1);
      expect(s.content!.passageCount, 1);
      expect(s.textScale, 1.3);
    });

    test('unknown passage fails to load', () async {
      await open(const ReadArgs(passageId: 'nope'));
      expect(state().phase, isA<ReadLoadFailed>());
    });

    test('word index outside the passage fails to load', () async {
      await open(
        ReadArgs(passageId: teaPassage.id, mode: ReadMode.word, wordIndex: 99),
      );
      expect(state().phase, isA<ReadLoadFailed>());
    });

    test('sentence mode shows the sentence containing the word', () async {
      await open(
        ReadArgs(
          passageId: riverPassage.id,
          mode: ReadMode.sentence,
          wordIndex: 9,
        ),
      );
      final c = state().content!;
      expect(c.target.text, 'We passed an old castle and a farm');
      expect(c.firstWordIndex, 7);
      expect(c.passageNumber, isNull);
    });

    test('word mode shows the single word', () async {
      await open(
        ReadArgs(passageId: riverPassage.id, mode: ReadMode.word, wordIndex: 1),
      );
      expect(state().content!.target.text, 'Thursday');
      expect(state().content!.firstWordIndex, 1);
    });
  });

  group('model tier', () {
    test('warms up the recommended tier when it is on the phone', () async {
      await open(
        passageArgs,
        harness: ReadHarness(recognizer: TestRecognizer(fullAvailable: true)),
      );
      await until(() => h.recognizer.loadedTier != null);
      expect(h.recognizer.loads, [ModelTier.full]);
      expect(controller().wantedTier, ModelTier.full);
    });

    test('falls back to light when full is not downloaded', () async {
      final c = await open(passageArgs);
      expect(await recordAndStop(c), isA<ReadDone>());
      expect(h.recognizer.loadedTier, ModelTier.light);
      expect((state().phase as ReadDone).result.tier, ModelTier.light);
    });

    test('the user override wins over the recommendation', () async {
      final c = await open(
        passageArgs,
        harness: ReadHarness(
          recognizer: TestRecognizer(fullAvailable: true),
          profile: const UserProfile(tierOverride: ModelTier.light),
        ),
      );
      await recordAndStop(c);
      expect(h.recognizer.loads, [ModelTier.light]);
      expect((state().phase as ReadDone).result.tier, ModelTier.light);
    });

    test('override full is used when downloaded', () async {
      final c = await open(
        passageArgs,
        harness: ReadHarness(
          recognizer: TestRecognizer(
            recommended: ModelTier.light,
            fullAvailable: true,
          ),
          profile: const UserProfile(tierOverride: ModelTier.full),
        ),
      );
      await recordAndStop(c);
      expect((state().phase as ReadDone).result.tier, ModelTier.full);
    });

    test('switches to full once the download has finished', () async {
      final c = await open(passageArgs);
      await recordAndStop(c);
      expect(h.recognizer.loadedTier, ModelTier.light);
      h.recognizer.fullAvailable = true;
      container.invalidate(scoringControllerProvider(args));
      await until(() => state().phase is ReadIdle);
      await recordAndStop(controller());
      expect(h.recognizer.loads, [ModelTier.light, ModelTier.full]);
    });

    test('shows a notice while the wanted full tier downloads', () async {
      final c = await open(passageArgs);
      await until(() => c.wantedTier != null);
      h.recognizer.emitDownload(
        const ModelDownloadProgress(
          state: DownloadState.downloading,
          receivedBytes: 40,
          totalBytes: 100,
        ),
      );
      await until(() => state().downloadNotice != null);
      expect(state().downloadNotice!.fraction, 0.4);
      h.recognizer.emitDownload(
        const ModelDownloadProgress(
          state: DownloadState.completed,
          receivedBytes: 100,
          totalBytes: 100,
        ),
      );
      await until(() => state().downloadNotice == null);
    });

    test('no notice when light is wanted', () async {
      final c = await open(
        passageArgs,
        harness: ReadHarness(
          profile: const UserProfile(tierOverride: ModelTier.light),
        ),
      );
      await until(() => c.wantedTier != null);
      h.recognizer.emitDownload(
        const ModelDownloadProgress(state: DownloadState.downloading),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(state().downloadNotice, isNull);
    });

    test('waits for a running download when no tier is on the phone', () async {
      final recognizer = TestRecognizer(lightAvailable: false)
        ..statusOverride = const ModelDownloadProgress(
          state: DownloadState.downloading,
          receivedBytes: 10,
          totalBytes: 100,
        );
      final c = await open(
        passageArgs,
        harness: ReadHarness(recognizer: recognizer),
      );
      await c.startRecording();
      unawaited(c.stopRecording());
      await until(
        () =>
            state().phase is ReadScoring &&
            (state().phase as ReadScoring).stage ==
                ScoringStage.waitingForDownload,
      );
      expect((state().phase as ReadScoring).progress, closeTo(0.1, 1e-9));
      recognizer.emitDownload(
        const ModelDownloadProgress(
          state: DownloadState.downloading,
          receivedBytes: 50,
          totalBytes: 100,
        ),
      );
      await until(() => (state().phase as ReadScoring).progress == 0.5);
      recognizer.emitDownload(
        const ModelDownloadProgress(
          state: DownloadState.completed,
          receivedBytes: 100,
          totalBytes: 100,
        ),
      );
      await until(() => state().phase is ReadDone);
      expect((state().phase as ReadDone).result.tier, ModelTier.full);
    });

    test('a failed download while waiting is an error', () async {
      final recognizer = TestRecognizer(lightAvailable: false)
        ..statusOverride = const ModelDownloadProgress(
          state: DownloadState.downloading,
        );
      final c = await open(
        passageArgs,
        harness: ReadHarness(recognizer: recognizer),
      );
      await c.startRecording();
      unawaited(c.stopRecording());
      await until(() => state().phase is ReadScoring);
      await until(
        () =>
            (state().phase as ReadScoring).stage ==
            ScoringStage.waitingForDownload,
      );
      recognizer.emitDownload(
        const ModelDownloadProgress(state: DownloadState.failed),
      );
      await until(() => state().phase is ReadFailed);
      expect((state().phase as ReadFailed).message, contains('speech model'));
      expect(h.deleted, [h.recorder.clip.path]);
    });

    test('no model and no download is an error', () async {
      final c = await open(
        passageArgs,
        harness: ReadHarness(recognizer: TestRecognizer(lightAvailable: false)),
      );
      expect(await recordAndStop(c), isA<ReadFailed>());
      expect(h.engine.recorded, isEmpty);
    });

    test('cancel while waiting for the download returns to idle', () async {
      final recognizer = TestRecognizer(lightAvailable: false)
        ..statusOverride = const ModelDownloadProgress(
          state: DownloadState.waitingForWifi,
        );
      final c = await open(
        passageArgs,
        harness: ReadHarness(recognizer: recognizer),
      );
      await c.startRecording();
      final stopping = c.stopRecording();
      await until(
        () =>
            state().phase is ReadScoring &&
            (state().phase as ReadScoring).stage ==
                ScoringStage.waitingForDownload,
      );
      await c.cancelScoring();
      await stopping;
      expect(state().phase, isA<ReadIdle>());
      expect(recognizer.recogniseCount, 0);
    });
  });

  group('practice time', () {
    for (final mode in [ReadMode.passage, ReadMode.sentence, ReadMode.word]) {
      test('is logged after a $mode recording', () async {
        final c = await open(
          ReadArgs(passageId: riverPassage.id, mode: mode, wordIndex: 1),
        );
        await recordAndStop(c);
        expect(h.engine.practiceLogged, [h.recorder.clip.duration]);
        expect(
          (await h.progress.practiceSessions()).single.duration,
          h.recorder.clip.duration,
        );
      });
    }

    test('is not logged for placement', () async {
      final c = await open(
        ReadArgs(passageId: teaPassage.id, mode: ReadMode.placement),
      );
      await recordAndStop(c);
      expect(state().phase, isA<ReadDone>());
      expect(h.engine.practiceLogged, isEmpty);
    });

    test('is logged even when the audio is too quiet', () async {
      final h0 = ReadHarness();
      h0.recorder.clip = h0.recorder.clip.copyWith(
        quality: AudioQuality.tooQuiet,
        duration: const Duration(seconds: 4),
      );
      final c = await open(passageArgs, harness: h0);
      await recordAndStop(c);
      expect(h.engine.practiceLogged, [const Duration(seconds: 4)]);
    });

    test('a failing log does not block scoring', () async {
      final h0 = ReadHarness();
      final c = await open(passageArgs, harness: h0);
      await h0.progress.deleteAll();
      expect(await recordAndStop(c), isA<ReadDone>());
    });
  });

  group('modes', () {
    test(
      'passage: saves through recordAttempt and keeps the audio path',
      () async {
        final c = await open(passageArgs);
        final phase = await recordAndStop(c) as ReadDone;
        expect(h.engine.recorded.single.id, phase.result.id);
        expect(phase.result.audioPath, h.recorder.clip.path);
        expect(phase.result.passageId, riverPassage.id);
        expect(phase.result.at, h.now);
        expect(await h.progress.attempt(phase.result.id), isNotNull);
        expect(h.deleted, isEmpty);
      },
    );

    test('passage: returns the level change', () async {
      final c = await open(
        ReadArgs(passageId: teaPassage.id),
        harness: ReadHarness(profile: const UserProfile(level: 1)),
      );
      LevelChange? change;
      for (var i = 0; i < 3; i++) {
        final phase = await recordAndStop(c) as ReadDone;
        change = phase.levelChange;
        container.invalidate(scoringControllerProvider(args));
        await until(() => state().phase is ReadIdle);
        if (i < 2) expect(change, isNull);
      }
      expect(change, isNotNull);
      expect(change!.to, 2);
    });

    test('placement: scores the whole passage and saves nothing', () async {
      final c = await open(
        ReadArgs(passageId: linkingPassage.id, mode: ReadMode.placement),
      );
      final phase = await recordAndStop(c) as ReadDone;
      expect(phase.result.words, hasLength(linkingPassage.words.length));
      expect(phase.result.audioPath, isNull);
      expect(h.engine.recorded, isEmpty);
      expect(await h.progress.attempts(), isEmpty);
      expect(h.deleted, [h.recorder.clip.path]);
    });

    test('sentence: words keep their passage indices', () async {
      final c = await open(
        ReadArgs(
          passageId: riverPassage.id,
          mode: ReadMode.sentence,
          wordIndex: 9,
        ),
      );
      final phase = await recordAndStop(c) as ReadDone;
      expect(phase.result.passageId, riverPassage.id);
      expect(
        [for (final w in phase.result.words) w.index],
        [for (var i = 7; i < 15; i++) i],
      );
      expect(phase.result.words.first.text, 'We');
      expect(h.engine.recorded, isEmpty);
      expect(h.deleted, [h.recorder.clip.path]);
    });

    test('word: one word result from scoreWord', () async {
      final c = await open(
        ReadArgs(passageId: riverPassage.id, mode: ReadMode.word, wordIndex: 1),
      );
      final phase = await recordAndStop(c) as ReadDone;
      final w = phase.result.words.single;
      expect(w.index, 1);
      expect(w.text, 'Thursday');
      expect(phase.result.overall, w.score);
      expect(phase.result.accuracy, 45);
      expect(phase.result.tier, ModelTier.light);
      expect(h.engine.recorded, isEmpty);
    });
  });

  group('recording', () {
    test(
      'level values feed the waveform and the timer uses the clock',
      () async {
        final h0 = ReadHarness(
          recorder: FakeAudioRecorder(
            levels: [0.1, 0.5, 2.0],
            levelInterval: const Duration(milliseconds: 1),
            emitSilenceAfterLevels: false,
          ),
        );
        final c = await open(passageArgs, harness: h0);
        await c.startRecording();
        h.now = h.now.add(const Duration(seconds: 3));
        await until(() => (state().phase as ReadRecording).levels.length == 3);
        final phase = state().phase as ReadRecording;
        expect(phase.levels, [0.1, 0.5, 1.0]);
        expect(phase.elapsed, const Duration(seconds: 3));
        await c.discardRecording();
      },
    );

    test('waveform keeps only the latest values', () async {
      final h0 = ReadHarness(
        recorder: FakeAudioRecorder(
          levels: [for (var i = 0; i < waveformLength + 10; i++) 0.5],
          levelInterval: const Duration(microseconds: 100),
          emitSilenceAfterLevels: false,
        ),
      );
      final c = await open(passageArgs, harness: h0);
      var emitted = 0;
      final sub = h0.recorder.level.listen((_) => emitted++);
      addTearDown(sub.cancel);
      await c.startRecording();
      // Wait for every level value (not a fixed 100 ms, which a busy machine can miss).
      await until(
        () => emitted == waveformLength + 10,
        reason: 'all levels emitted',
      );
      await pumpEventQueue();
      expect(
        (state().phase as ReadRecording).levels,
        hasLength(waveformLength),
      );
      await c.discardRecording();
    });

    test('2 s of silence stops and scores by itself', () async {
      final h0 = ReadHarness(
        recorder: FakeAudioRecorder(
          levels: [0.4, 0.4],
          levelInterval: const Duration(milliseconds: 1),
        ),
      );
      final c = await open(passageArgs, harness: h0);
      await c.startRecording();
      await until(() => state().phase is ReadDone);
      expect(h.recorder.isRecording, isFalse);
    });

    test('stops at the time limit', () async {
      final c = await open(passageArgs);
      await c.startRecording();
      h.now = h.now.add(maxRecordingDuration);
      await until(() => state().phase is ReadDone);
    });

    test('discard cancels without scoring or logging', () async {
      final c = await open(passageArgs);
      await c.startRecording();
      await c.discardRecording();
      expect(state().phase, isA<ReadIdle>());
      expect(h.recorder.isRecording, isFalse);
      expect(h.engine.practiceLogged, isEmpty);
      await c.discardRecording(); // no-op when not recording
      await c.stopRecording(); // no-op when not recording
      expect(state().phase, isA<ReadIdle>());
    });

    test('ignores start while recording', () async {
      final c = await open(passageArgs);
      await c.startRecording();
      await c.startRecording();
      expect(h.recorder.startCount, 1);
      await c.discardRecording();
    });

    test('a recorder that fails to start shows an error', () async {
      final c = await open(passageArgs);
      await h.recorder.start(); // the recorder is busy: start throws StateError
      await c.startRecording();
      expect(state().phase, isA<ReadFailed>());
      c.reset();
      expect(state().phase, isA<ReadIdle>());
      await h.recorder.cancel();
    });

    test('disposing while recording cancels the recording', () async {
      final c = await open(passageArgs);
      await c.startRecording();
      expect(h.recorder.isRecording, isTrue);
      container.dispose();
      expect(h.recorder.isRecording, isFalse);
    });
  });

  group('audio checks', () {
    for (final (quality, reason) in [
      (AudioQuality.tooQuiet, RetryReason.tooQuiet),
      (AudioQuality.tooNoisy, RetryReason.tooNoisy),
    ]) {
      test('$quality asks for a retry and deletes the clip', () async {
        final h0 = ReadHarness();
        h0.recorder.clip = h0.recorder.clip.copyWith(quality: quality);
        final c = await open(passageArgs, harness: h0);
        final phase = await recordAndStop(c);
        expect(phase, isA<ReadRetryNeeded>());
        expect((phase as ReadRetryNeeded).reason, reason);
        expect(h.deleted, [h.recorder.clip.path]);
        expect(h.recognizer.recogniseCount, 0);
        // Try again records straight away.
        await c.startRecording();
        expect(state().phase, isA<ReadRecording>());
        await c.discardRecording();
      });
    }

    test('no speech asks for a retry', () async {
      final h0 = ReadHarness(
        recorder: FakeAudioRecorder(
          levels: const [],
          emitSilenceAfterLevels: false,
          segments: const [],
        ),
      );
      final c = await open(passageArgs, harness: h0);
      final phase = await recordAndStop(c);
      expect((phase as ReadRetryNeeded).reason, RetryReason.noSpeech);
      expect(h.deleted, [h.recorder.clip.path]);
    });
  });

  group('permission', () {
    test('asks once, then shows denied', () async {
      final h0 = ReadHarness(
        recorder: FakeAudioRecorder(
          permission: MicPermission.denied,
          permissionAfterRequest: MicPermission.denied,
        ),
      );
      final c = await open(passageArgs, harness: h0);
      await c.startRecording();
      final phase = state().phase as ReadPermissionDenied;
      expect(phase.permanently, isFalse);
      // Granting from the prompt goes back to ready.
      h0.recorder.permissionAfterRequest = MicPermission.granted;
      await c.requestPermission();
      expect(state().phase, isA<ReadIdle>());
    });

    test('granting from the first prompt starts recording', () async {
      final h0 = ReadHarness(
        recorder: FakeAudioRecorder(
          permission: MicPermission.denied,
          levels: const [],
          emitSilenceAfterLevels: false,
        ),
      );
      final c = await open(passageArgs, harness: h0);
      await c.startRecording();
      expect(state().phase, isA<ReadRecording>());
      await c.discardRecording();
    });

    test('permanently denied opens settings and rechecks on resume', () async {
      final h0 = ReadHarness(
        recorder: FakeAudioRecorder(
          permission: MicPermission.permanentlyDenied,
        ),
      );
      final c = await open(passageArgs, harness: h0);
      await c.startRecording();
      expect((state().phase as ReadPermissionDenied).permanently, isTrue);
      expect(await c.openPermissionSettings(), isTrue);
      expect(h0.recorder.settingsOpened, 1);
      await c.recheckPermission();
      expect(state().phase, isA<ReadPermissionDenied>());
      await c.requestPermission();
      expect((state().phase as ReadPermissionDenied).permanently, isTrue);
      h0.recorder.permission = MicPermission.granted;
      await c.recheckPermission();
      expect(state().phase, isA<ReadIdle>());
      await c.recheckPermission(); // no-op outside the denied state
      expect(state().phase, isA<ReadIdle>());
    });

    test('a start that throws MicPermissionException shows denied', () async {
      final h0 = ReadHarness(recorder: _RevokingRecorder());
      final c = await open(passageArgs, harness: h0);
      await c.startRecording();
      expect((state().phase as ReadPermissionDenied).permanently, isTrue);
    });
  });

  group('scoring', () {
    test('shows progress while recognising and can be cancelled', () async {
      final c = await open(passageArgs);
      h.recognizer.gate = Completer<void>();
      await c.startRecording();
      final stopping = c.stopRecording();
      await until(
        () =>
            state().phase is ReadScoring &&
            (state().phase as ReadScoring).stage == ScoringStage.recognising,
      );
      final first = (state().phase as ReadScoring).progress;
      await until(() => (state().phase as ReadScoring).progress > first);
      await c.cancelScoring();
      expect(state().phase, isA<ReadIdle>());
      expect(h.deleted, [h.recorder.clip.path]);
      h.recognizer.gate!.complete();
      await stopping;
      expect(state().phase, isA<ReadIdle>());
      expect(h.engine.recorded, isEmpty);
      await c.cancelScoring(); // no-op outside scoring
    });

    test('a recognition error shows a retryable error', () async {
      final c = await open(passageArgs);
      h.recognizer.recogniseError = StateError('boom');
      final phase = await recordAndStop(c);
      expect(phase, isA<ReadFailed>());
      expect(h.deleted, [h.recorder.clip.path]);
      c.reset();
      expect(state().phase, isA<ReadIdle>());
      c.reset(); // no-op when idle
      expect(state().phase, isA<ReadIdle>());
    });

    test('a recorder stop failure shows an error', () async {
      final h0 = ReadHarness(recorder: _BrokenStopRecorder());
      final c = await open(passageArgs, harness: h0);
      expect(await recordAndStop(c), isA<ReadFailed>());
    });
  });

  group('text size', () {
    test('changes in steps, clamps and is saved', () async {
      final c = await open(passageArgs);
      await c.changeTextScale(textScaleStep);
      expect(state().textScale, 1.1);
      expect((await h.progress.profile()).textScale, 1.1);
      for (var i = 0; i < 20; i++) {
        await c.changeTextScale(textScaleStep);
      }
      expect(state().textScale, maxTextScale);
      for (var i = 0; i < 20; i++) {
        await c.changeTextScale(-textScaleStep);
      }
      expect(state().textScale, minTextScale);
      expect((await h.progress.profile()).textScale, minTextScale);
    });
  });

  test('a failing discard does not break the run', () async {
    final recorder = _FailingDiscardRecorder();
    final c = await open(
      ReadArgs(passageId: teaPassage.id, mode: ReadMode.word, wordIndex: 0),
      harness: ReadHarness(recorder: recorder),
    );
    final phase = await recordAndStop(c);
    expect(phase, isA<ReadDone>());
    expect(recorder.discardCalls, 1);
  });
}

class _FailingDiscardRecorder extends FakeAudioRecorder {
  _FailingDiscardRecorder()
    : super(levels: const [], emitSilenceAfterLevels: false);

  int discardCalls = 0;

  @override
  Future<void> discard(AudioClip clip) async {
    discardCalls++;
    throw StateError('disk gone');
  }
}

class _RevokingRecorder extends FakeAudioRecorder {
  @override
  Future<void> start() async =>
      throw const MicPermissionException(MicPermission.permanentlyDenied);
}

class _BrokenStopRecorder extends FakeAudioRecorder {
  _BrokenStopRecorder()
    : super(levels: const [], emitSilenceAfterLevels: false);

  @override
  Future<AudioClip> stop() async {
    await cancel();
    throw StateError('disk full');
  }
}
