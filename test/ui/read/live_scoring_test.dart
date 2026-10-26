import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/read/read_state.dart';
import 'package:uk_pronunciation_coach/ui/read/scoring_controller.dart';

import 'read_test_helpers.dart';

/// A recorder that also streams its audio.
class LiveFakeRecorder extends FakeAudioRecorder implements LiveAudioSource {
  LiveFakeRecorder() : super(levels: const [], emitSilenceAfterLevels: false);

  final blocks = StreamController<LiveAudioBlock>.broadcast(sync: true);
  Object? startError;

  @override
  Stream<LiveAudioBlock> get liveAudio => blocks.stream;

  @override
  Future<void> start() async {
    if (startError case final e?) throw e;
    await super.start();
  }
}

class SpyLive implements LiveRecognition {
  SpyLive(this.recognizer);
  final LiveRecognizer recognizer;
  final added = <LiveAudioBlock>[];
  bool cancelled = false;
  bool finished = false;
  Completer<void>? gate;
  Object? failWith;
  Object? addFailure;

  @override
  void add(LiveAudioBlock block) {
    if (addFailure case final e?) throw e;
    added.add(block);
  }

  @override
  Duration get pendingAudio => const Duration(seconds: 2);

  @override
  Future<PhonemePosteriors> finish(AudioClip clip) async {
    finished = true;
    if (gate != null) await gate!.future;
    if (failWith case final e?) throw e;
    return recognizer.liveResult;
  }

  @override
  void cancel() => cancelled = true;
}

class LiveRecognizer extends TestRecognizer
    implements IncrementalPhonemeRecognizer {
  final sessions = <SpyLive>[];
  Object? startFailure;
  PhonemePosteriors liveResult = riverPosteriors;
  int wholeClipCalls = 0;

  @override
  LiveRecognition startLiveRecognition() {
    if (startFailure case final e?) throw e;
    final s = SpyLive(this);
    sessions.add(s);
    return s;
  }

  @override
  Future<PhonemePosteriors> recognise(AudioClip clip) {
    wholeClipCalls++;
    return super.recognise(clip);
  }
}

void main() {
  late LiveFakeRecorder recorder;
  late LiveRecognizer recognizer;
  late ReadHarness h;
  late ProviderContainer container;
  final args = ReadArgs(passageId: riverPassage.id);

  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 500; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    fail('Timed out');
  }

  ReadState state() => container.read(scoringControllerProvider(args));

  Future<ScoringController> open({bool live = true}) async {
    recorder = LiveFakeRecorder();
    recognizer = LiveRecognizer();
    h = ReadHarness(recorder: recorder, recognizer: recognizer);
    container = ProviderContainer(overrides: h.overrides);
    addTearDown(container.dispose);
    container.listen(scoringControllerProvider(args), (_, _) {});
    await until(() => state().phase is! ReadLoading);
    final c = container.read(scoringControllerProvider(args).notifier);
    c.liveScoring = live;
    return c;
  }

  LiveAudioBlock block() => LiveAudioBlock(Float32List(320));

  test('the model is loaded as soon as the screen has opened', () async {
    await open();
    await until(() => recognizer.loads.isNotEmpty);
    expect(recognizer.loads, [ModelTier.light]);
  });

  test(
    'feeds the recording to live recognition and scores its result',
    () async {
      final c = await open();
      await c.startRecording();
      expect(recognizer.sessions, hasLength(1));
      recorder.blocks.add(block());
      recorder.blocks.add(block());
      expect(recognizer.sessions.single.added, hasLength(2));
      await c.stopRecording();
      await until(() => h.engine.recorded.isNotEmpty);
      expect(recognizer.sessions.single.finished, isTrue);
      expect(recognizer.wholeClipCalls, 0);
      expect(h.engine.recorded, hasLength(1));
      expect(
        recognizer.sessions.single.cancelled,
        isTrue,
        reason: 'cleaned up',
      );
    },
  );

  test('liveScoring off recognises the finished clip', () async {
    final c = await open(live: false);
    await c.startRecording();
    await c.stopRecording();
    await until(() => h.engine.recorded.isNotEmpty);
    expect(recognizer.sessions, isEmpty);
    expect(recognizer.wholeClipCalls, 1);
  });

  test('a recognizer without live support is used as before', () async {
    recorder = LiveFakeRecorder();
    final plain = TestRecognizer();
    h = ReadHarness(recorder: recorder, recognizer: plain);
    container = ProviderContainer(overrides: h.overrides);
    addTearDown(container.dispose);
    container.listen(scoringControllerProvider(args), (_, _) {});
    await until(() => state().phase is! ReadLoading);
    final c = container.read(scoringControllerProvider(args).notifier);
    await c.startRecording();
    recorder.blocks.add(block());
    await c.stopRecording();
    await until(() => h.engine.recorded.isNotEmpty);
  });

  test('a recognizer that cannot start a session falls back', () async {
    final c = await open();
    recognizer.startFailure = StateError('no');
    await c.startRecording();
    await c.stopRecording();
    await until(() => h.engine.recorded.isNotEmpty);
    expect(recognizer.wholeClipCalls, 1);
  });

  test(
    'a live session that throws on add is dropped, recording goes on',
    () async {
      final c = await open();
      await c.startRecording();
      final s = recognizer.sessions.single..addFailure = StateError('x');
      recorder.blocks.add(block());
      expect(s.cancelled, isTrue);
      expect(state().phase, isA<ReadRecording>());
      await c.stopRecording();
      await until(() => h.engine.recorded.isNotEmpty);
      expect(recognizer.wholeClipCalls, 1);
    },
  );

  test(
    'a failing finish is a retryable error; the retry starts afresh',
    () async {
      final c = await open();
      await c.startRecording();
      recognizer.sessions.single.failWith = StateError('boom');
      await c.stopRecording();
      await until(() => state().phase is ReadFailed);
      expect(h.deleted, [recorder.clip.path]);
      c.reset();
      await c.startRecording();
      expect(recognizer.sessions, hasLength(2));
      expect(recognizer.sessions.last.added, isEmpty);
      await c.stopRecording();
      await until(() => h.engine.recorded.isNotEmpty);
    },
  );

  test('cancelling while scoring drops the live session', () async {
    final c = await open();
    await c.startRecording();
    final s = recognizer.sessions.single..gate = Completer<void>();
    final stopping = c.stopRecording();
    await until(() => s.finished);
    await c.cancelScoring();
    expect(s.cancelled, isTrue);
    expect(state().phase, isA<ReadIdle>());
    s.gate!.complete();
    await stopping;
    expect(state().phase, isA<ReadIdle>());
    expect(h.engine.recorded, isEmpty);
  });

  test('discarding a recording drops the live session', () async {
    final c = await open();
    await c.startRecording();
    await c.discardRecording();
    expect(recognizer.sessions.single.cancelled, isTrue);
    expect(state().phase, isA<ReadIdle>());
  });

  test('a recorder that fails to start drops the live session', () async {
    final c = await open();
    recorder.startError = StateError('mic');
    await c.startRecording();
    expect(state().phase, isA<ReadFailed>());
    expect(recognizer.sessions.single.cancelled, isTrue);
  });

  test('a clip that is too quiet drops the live session', () async {
    final c = await open();
    recorder.clip = AudioClip(
      path: recorder.clip.path,
      duration: recorder.clip.duration,
      quality: AudioQuality.tooQuiet,
    );
    await c.startRecording();
    await c.stopRecording();
    expect(state().phase, isA<ReadRetryNeeded>());
    expect(recognizer.sessions.single.cancelled, isTrue);
  });
}
