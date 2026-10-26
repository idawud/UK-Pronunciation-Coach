import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/live_recognition.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/runtime/chunk_planner.dart';
import 'package:uk_pronunciation_coach/engine/runtime/live_recognition_session.dart';

const _vocab = ['<pad>', 'a', 'b'];

/// A fake model: each sample's value is its index in the recording, so a piece
/// knows where it starts; frame j of a piece starting at sample `lo` gets the
/// value `lo / 320 + j` in column 0 (its global frame number).
class FakeModel {
  final calls = <(int lo, int length)>[];
  ModelTier tier = ModelTier.light;
  Object? failWith;
  Completer<void>? gate;

  Future<ChunkPosteriors?> call(
    Float32List samples, {
    required bool Function() skip,
  }) async {
    if (gate != null) await gate!.future;
    if (skip()) return null;
    final lo = samples.first.round();
    calls.add((lo, samples.length));
    if (failWith != null) throw failWith!;
    final frames = framesForSamples(samples.length);
    final data = Float32List(frames * _vocab.length);
    for (var j = 0; j < frames; j++) {
      data[j * _vocab.length] = (lo ~/ frameSamples + j).toDouble();
      data[j * _vocab.length + 1] = -1;
      data[j * _vocab.length + 2] = -2;
    }
    return ChunkPosteriors(
      tier: tier,
      logProbs: data,
      frames: frames,
      vocab: _vocab,
      blankIndex: 0,
    );
  }
}

/// Probabilities for [ms] of speech (0.9) or pause (0.05), 32 ms per chunk.
List<double> probs(int ms, {required bool speech}) => [
  for (var i = 0; i < ms ~/ 32; i++) speech ? 0.9 : 0.05,
];

class Feeder {
  Feeder(this.session);
  final LiveRecognition session;
  final _probabilities = <double>[];
  int _emitted = 0;
  int samples = 0;

  /// Adds audio covered by [p] (512 samples per probability), in 20 ms blocks
  /// whose probabilities are delivered as each 512-sample chunk completes.
  void add(List<double> p) {
    _probabilities.addAll(p);
    final end = _probabilities.length * 512;
    while (samples < end) {
      final n = (end - samples).clamp(0, 320);
      final block = Float32List(n);
      for (var i = 0; i < n; i++) {
        block[i] = (samples + i).toDouble();
      }
      samples += n;
      final done = <double>[];
      while ((_emitted + 1) * 512 <= samples) {
        done.add(_probabilities[_emitted++]);
      }
      session.add(LiveAudioBlock(block, speechProbabilities: done));
    }
  }

  AudioClip clip({int? samplesOverride}) => AudioClip(
    path: 'x.wav',
    duration: Duration(
      microseconds: (samplesOverride ?? samples) * 1000000 ~/ 16000,
    ),
  );
}

PhonemePosteriors wholeClipMarker(AudioClip clip) => PhonemePosteriors(
  vocab: _vocab,
  frames: [
    Float32List.fromList([-99, 0, 0]),
  ],
  blankIndex: 0,
  frameMs: 20,
  tier: ModelTier.full,
);

void main() {
  late FakeModel model;
  late List<AudioClip> wholeCalls;
  late ModelTier? loaded;

  LiveRecognitionSession session({
    bool fill = true,
    LiveChunking chunking = const LiveChunking(),
  }) => LiveRecognitionSession(
    recognise: model.call,
    wholeClip: (clip) async {
      wholeCalls.add(clip);
      return wholeClipMarker(clip);
    },
    loadedTier: () => loaded,
    fillPausedTail: fill,
    settings: chunking,
  );

  setUp(() {
    model = FakeModel();
    wholeCalls = [];
    loaded = ModelTier.light;
  });

  void expectAligned(PhonemePosteriors p, int samples, {int? upTo}) {
    expect(p.frames, hasLength(framesForSamples(samples)));
    for (var f = 0; f < (upTo ?? p.frames.length); f++) {
      expect(p.frames[f][0], f.toDouble(), reason: 'frame $f');
    }
  }

  test('recognises pieces during the recording and joins them', () async {
    final s = session();
    final feeder = Feeder(s)
      ..add(probs(2016, speech: true))
      ..add(probs(608, speech: false))
      ..add(probs(2016, speech: true))
      ..add(probs(608, speech: false));
    await Future<void>.delayed(Duration.zero);
    expect(model.calls, hasLength(2), reason: 'two pauses, two pieces');
    expect(s.stats.backgroundChunks, 2);
    feeder.add(probs(1504, speech: true));
    final p = await s.finish(feeder.clip());
    expect(wholeCalls, isEmpty);
    expect(model.calls, hasLength(3), reason: 'only the tail is left');
    expect(s.stats.tailSamples, greaterThan(0));
    expect(s.stats.tailFilled, isFalse);
    expect(s.stats.fallbackReason, isNull);
    expect(p.tier, ModelTier.light);
    expect(p.frameMs, 20);
    expect(p.blankIndex, 0);
    expectAligned(p, feeder.samples);
    // Pieces overlap by the context on each side.
    expect(model.calls[1].$1, lessThan(model.calls[0].$1 + model.calls[0].$2));
  });

  test('a recording without pauses is one piece at the end', () async {
    final s = session();
    final feeder = Feeder(s)..add(probs(3008, speech: true));
    expect(s.pendingAudio.inMilliseconds, closeTo(3008, 1));
    final p = await s.finish(feeder.clip());
    expect(model.calls, hasLength(1));
    expect(model.calls.single.$1, 0);
    expectAligned(p, feeder.samples);
  });

  test('a pause after the last piece is filled, not recognised', () async {
    final s = session();
    final feeder = Feeder(s)
      ..add(probs(2016, speech: true))
      ..add(probs(2016, speech: false));
    final p = await s.finish(feeder.clip());
    expect(model.calls, hasLength(1));
    expect(s.stats.tailFilled, isTrue);
    expect(s.stats.tailSamples, 0);
    final cut = model.calls.single.$1 + 0; // piece starts at 0
    expect(cut, 0);
    final lastKept = p.frames.indexWhere((f) => f[0] != p.frames.indexOf(f));
    expect(lastKept, greaterThan(0));
    // Every frame after the piece repeats the piece's last frame.
    final filledFrom = lastKept;
    for (var f = filledFrom; f < p.frames.length; f++) {
      expect(p.frames[f][0], (filledFrom - 1).toDouble());
    }
    expect(p.frames, hasLength(framesForSamples(feeder.samples)));
  });

  test('with fillPausedTail off the pause is recognised', () async {
    final s = session(fill: false);
    final feeder = Feeder(s)
      ..add(probs(2016, speech: true))
      ..add(probs(2016, speech: false));
    final p = await s.finish(feeder.clip());
    expect(model.calls, hasLength(2));
    expectAligned(p, feeder.samples);
  });

  test('a cut still waiting for its context is part of the tail', () async {
    // The cut lands 150 ms into the pause; with 400 ms of context the 320 ms of
    // pause heard so far is not enough to run the piece yet.
    final s = session(
      chunking: const LiveChunking(context: Duration(milliseconds: 400)),
    );
    final feeder = Feeder(s)
      ..add(probs(2016, speech: true))
      ..add(probs(320, speech: false));
    await Future<void>.delayed(Duration.zero);
    expect(model.calls, isEmpty);
    final p = await s.finish(feeder.clip());
    expect(model.calls, hasLength(1));
    expectAligned(p, feeder.samples);
  });

  test('falls back to the whole clip when the audio does not match', () async {
    final s = session();
    final feeder = Feeder(s)..add(probs(1024, speech: true));
    final p = await s.finish(
      feeder.clip(samplesOverride: feeder.samples + 999),
    );
    expect(wholeCalls, hasLength(1));
    expect(p.frames.single[0], -99);
    expect(s.stats.fallbackReason, contains('does not match'));
  });

  test('falls back when there was no live audio', () async {
    final s = session();
    await s.finish(const AudioClip(path: 'x.wav', duration: Duration.zero));
    expect(wholeCalls, hasLength(1));
    expect(s.stats.fallbackReason, 'no live audio');
  });

  test('falls back when a piece fails', () async {
    model.failWith = StateError('boom');
    final s = session();
    final feeder = Feeder(s)
      ..add(probs(2016, speech: true))
      ..add(probs(608, speech: false))
      ..add(probs(1024, speech: true));
    await s.finish(feeder.clip());
    expect(wholeCalls, hasLength(1));
    expect(s.stats.fallbackReason, contains('boom'));
  });

  test('falls back when the model changed during the recording', () async {
    final s = session();
    final feeder = Feeder(s)
      ..add(probs(2016, speech: true))
      ..add(probs(608, speech: false));
    await Future<void>.delayed(Duration.zero);
    model.tier = ModelTier.full;
    feeder.add(probs(1024, speech: true));
    await s.finish(feeder.clip());
    expect(wholeCalls, hasLength(1));
    expect(s.stats.fallbackReason, contains('model changed'));

    model.tier = ModelTier.light;
    final s2 = session();
    final f2 = Feeder(s2)..add(probs(1024, speech: true));
    loaded = ModelTier.full;
    await s2.finish(f2.clip());
    expect(wholeCalls, hasLength(2));
  });

  test('cancel skips pending pieces and stops the session', () async {
    model.gate = Completer<void>();
    final s = session();
    final feeder = Feeder(s)
      ..add(probs(2016, speech: true))
      ..add(probs(608, speech: false));
    s.cancel();
    model.gate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(model.calls, isEmpty, reason: 'skipped');
    feeder.add(probs(1024, speech: true)); // ignored
    expect(() => s.finish(feeder.clip()), throwsStateError);
  });

  test('cancel while finishing makes finish fail', () async {
    model.gate = Completer<void>();
    final s = session();
    final feeder = Feeder(s)..add(probs(1024, speech: true));
    final done = s.finish(feeder.clip());
    s.cancel();
    model.gate!.complete();
    await expectLater(done, throwsStateError);
  });

  test('a piece skipped without cancel falls back', () async {
    final s = LiveRecognitionSession(
      recognise: (samples, {required skip}) async => null,
      wholeClip: (clip) async {
        wholeCalls.add(clip);
        return wholeClipMarker(clip);
      },
      loadedTier: () => loaded,
    );
    final feeder = Feeder(s)..add(probs(1024, speech: true));
    await s.finish(feeder.clip());
    expect(wholeCalls, hasLength(1));
    expect(s.stats.fallbackReason, 'a piece was skipped');
  });

  test('finish runs once', () async {
    final s = session();
    final feeder = Feeder(s)..add(probs(1024, speech: true));
    await s.finish(feeder.clip());
    expect(() => s.finish(feeder.clip()), throwsStateError);
    feeder.add(probs(64, speech: true)); // ignored after finish
  });

  test('pendingAudio counts unscheduled and running audio', () async {
    model.gate = Completer<void>();
    final s = session();
    final feeder = Feeder(s)
      ..add(probs(2016, speech: true))
      ..add(probs(608, speech: false));
    final running = s.pendingAudio;
    expect(running.inMilliseconds, greaterThan(2000));
    model.gate!.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(s.pendingAudio, lessThan(running));
    await s.finish(feeder.clip());
  });

  test('pieces end exactly on the last sample of the clip', () async {
    // The last frame of a clip whose length is not a whole number of frames.
    final s = session();
    final feeder = Feeder(s)..add(probs(992, speech: true));
    s.add(LiveAudioBlock(Float32List(0)));
    final extra = Float32List.fromList([
      for (var i = 0; i < 123; i++) (feeder.samples + i).toDouble(),
    ]);
    s.add(LiveAudioBlock(extra));
    final total = feeder.samples + 123;
    final p = await s.finish(feeder.clip(samplesOverride: total));
    expectAligned(p, total);
  });
}
