import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/contracts/live_recognition.dart';
import '../../core/models/audio_clip.dart';
import '../../core/models/enums.dart';
import '../../core/models/phoneme_posteriors.dart';
import 'chunk_planner.dart';

/// Log-posteriors of one piece of audio, as the model produced them.
class ChunkPosteriors {
  /// Creates the result.
  const ChunkPosteriors({
    required this.tier,
    required this.logProbs,
    required this.frames,
    required this.vocab,
    required this.blankIndex,
  });

  /// Tier of the model that ran.
  final ModelTier tier;

  /// Row-major `[frames, vocab.length]` natural-log probabilities.
  final Float32List logProbs;

  /// Number of frames.
  final int frames;

  /// Model symbols.
  final List<String> vocab;

  /// CTC blank column.
  final int blankIndex;
}

/// Runs the model on raw 16 kHz samples (normalised inside). Returns null when
/// [skip] says the work is no longer wanted by the time it would start.
typedef SampleRecogniser = Future<ChunkPosteriors?> Function(
  Float32List samples, {
  required bool Function() skip,
});

/// What a [LiveRecognitionSession] did, for benchmarks and diagnostics.
class LiveRecognitionStats {
  /// Pieces recognised in the background while recording.
  int backgroundChunks = 0;

  /// Audio recognised in the background (after the context is added).
  int backgroundSamples = 0;

  /// Audio [LiveRecognitionSession.finish] still had to run (0 when the tail was a
  /// pause and was filled with the pause before it).
  int tailSamples = 0;

  /// Whether the tail was a pause filled without running the model.
  bool tailFilled = false;

  /// Why [LiveRecognitionSession.finish] recognised the whole clip instead, if it did.
  String? fallbackReason;
}

/// [LiveRecognition] that cuts the recording in pauses ([ChunkPlanner]), runs each
/// piece (plus [LiveChunking.context] on both sides) in the background as soon as it
/// is complete, and on [finish] runs only what is left, then joins the frames.
///
/// Frames line up with whole-clip recognition: pieces start on 20 ms frame
/// boundaries, and the joined posteriors have exactly the whole clip's frame count.
/// The posteriors are close to, not identical with, whole-clip ones: wav2vec2's
/// attention and per-clip normalisation see one piece instead of the whole clip
/// (measured in docs/handoff/perf-speed.md).
class LiveRecognitionSession implements LiveRecognition {
  /// Creates a session; [recognise] runs pieces, [wholeClip] is the fallback.
  LiveRecognitionSession({
    required this._recognise,
    required this._wholeClip,
    required this._loadedTier,
    this.settings = const LiveChunking(),
    this.frameMs = 20,
    this.fillPausedTail = true,
  }) : _planner = ChunkPlanner(settings);

  /// Chunking settings.
  final LiveChunking settings;

  /// Frame hop of the posteriors.
  final int frameMs;

  /// When the audio after the last cut holds no speech, repeat the last frame of
  /// the piece before it (a pause) instead of running the model on it.
  final bool fillPausedTail;

  final SampleRecogniser _recognise;
  final Future<PhonemePosteriors> Function(AudioClip clip) _wholeClip;
  final ModelTier? Function() _loadedTier;
  final ChunkPlanner _planner;
  final _audio = _SampleBuffer();
  final _pendingCuts = <int>[];
  final _chunks = <_Chunk>[];
  int _scheduled = 0;
  bool _cancelled = false;
  bool _finished = false;

  /// What happened (filled in as the session runs).
  final stats = LiveRecognitionStats();

  @override
  Duration get pendingAudio {
    var samples = _audio.length - _scheduled;
    for (final c in _chunks) {
      if (!c.done) samples += c.hi - c.lo;
    }
    return Duration(microseconds: samples * 1000000 ~/ settings.sampleRate);
  }

  @override
  void add(LiveAudioBlock block) {
    if (_cancelled || _finished || block.samples.isEmpty) return;
    _audio.add(block.samples);
    _pendingCuts.addAll(
      _planner.add(
        block.samples.length,
        block.speechProbabilities,
        chunkSamples: block.speechChunkSamples,
      ),
    );
    final context = settings.contextSamples;
    while (_pendingCuts.isNotEmpty &&
        _pendingCuts.first + context <= _audio.length) {
      final cut = _pendingCuts.removeAt(0);
      _launch(_scheduled, cut, last: false);
      stats
        ..backgroundChunks += 1
        ..backgroundSamples += _chunks.last.hi - _chunks.last.lo;
    }
  }

  void _launch(int start, int end, {required bool last}) {
    final context = settings.contextSamples;
    final lo = math.max(0, start - context);
    final hi = last ? _audio.length : math.min(_audio.length, end + context);
    final chunk = _Chunk(start, end, lo, hi, last: last);
    chunk.result = _recognise(
      _audio.copy(lo, hi),
      skip: () => _cancelled,
    ).whenComplete(() => chunk.done = true);
    // Errors are handled in finish(); never let them go unhandled meanwhile.
    chunk.result.ignore();
    _chunks.add(chunk);
    _scheduled = end;
  }

  @override
  Future<PhonemePosteriors> finish(AudioClip clip) async {
    if (_cancelled) throw StateError('Live recognition was cancelled');
    if (_finished) throw StateError('Live recognition already finished');
    _finished = true;
    final total = _audio.length;
    final expected = Duration(
      microseconds: total * 1000000 ~/ settings.sampleRate,
    );
    if (clip.sampleRate != settings.sampleRate || clip.duration != expected) {
      return _fallback(clip, 'live audio does not match the clip');
    }
    if (total == 0) return _fallback(clip, 'no live audio');
    // Cuts whose right-hand context had not arrived yet: the tail starts at the
    // first of them (the pieces it spans are run together).
    _pendingCuts.clear();
    final tailStart = _scheduled;
    final previous = _chunks.isEmpty ? null : _chunks.last;
    if (tailStart < total) {
      if (fillPausedTail &&
          previous != null &&
          !_planner.speechFrom(tailStart)) {
        stats.tailFilled = true;
        _chunks.add(
          _Chunk(tailStart, total, tailStart, total, last: true, filled: true)
            ..result = Future.value()
            ..done = true,
        );
      } else {
        _launch(tailStart, total, last: true);
        stats.tailSamples = _chunks.last.hi - _chunks.last.lo;
      }
    } else if (_chunks.isNotEmpty) {
      _chunks.last.last = true;
    }
    final List<ChunkPosteriors?> outputs;
    try {
      outputs = await Future.wait([for (final c in _chunks) c.result]);
    } on Object catch (e) {
      return _fallback(clip, 'a piece failed: $e');
    }
    if (_cancelled) throw StateError('Live recognition was cancelled');
    for (var i = 0; i < _chunks.length; i++) {
      if (outputs[i] == null && !_chunks[i].filled) {
        return _fallback(clip, 'a piece was skipped');
      }
    }
    final real = outputs.whereType<ChunkPosteriors>().toList();
    final tier = real.first.tier;
    final vocab = real.first.vocab;
    if (real.any((o) => o.tier != tier || o.vocab.length != vocab.length) ||
        _loadedTier() != tier) {
      return _fallback(clip, 'the model changed during the recording');
    }
    return _join(total, outputs, tier, real.first);
  }

  PhonemePosteriors _join(
    int total,
    List<ChunkPosteriors?> outputs,
    ModelTier tier,
    ChunkPosteriors first,
  ) {
    final width = first.vocab.length;
    final frames = framesForSamples(total);
    final data = Float32List(frames * width);
    var filled = 0; // frames written so far
    for (var i = 0; i < _chunks.length; i++) {
      final chunk = _chunks[i];
      final out = outputs[i];
      final f0 = chunk.start ~/ frameSamples;
      final f1 = chunk.last ? frames : chunk.end ~/ frameSamples;
      if (out == null) {
        // A pause after the last piece: repeat that piece's last frame.
        _repeat(data, width, from: filled - 1, at: f0, until: f1);
        filled = f1;
        continue;
      }
      final offset = (chunk.start - chunk.lo) ~/ frameSamples;
      final available = math.max(0, out.frames - offset);
      final n = math.min(f1 - f0, available);
      if (n > 0) {
        data.setRange(
          f0 * width,
          (f0 + n) * width,
          out.logProbs,
          offset * width,
        );
      }
      // Rounding at the very end of the clip: repeat the last frame produced.
      if (f0 + n < f1) {
        _repeat(data, width, from: f0 + n - 1, at: f0 + n, until: f1);
      }
      filled = f1;
    }
    return PhonemePosteriors(
      vocab: first.vocab,
      frames: List<Float32List>.generate(
        frames,
        (f) => Float32List.sublistView(data, f * width, (f + 1) * width),
        growable: false,
      ),
      blankIndex: first.blankIndex,
      frameMs: frameMs,
      tier: tier,
    );
  }

  static void _repeat(
    Float32List data,
    int width, {
    required int from,
    required int at,
    required int until,
  }) {
    if (from < 0) return;
    for (var f = at; f < until; f++) {
      data.setRange(f * width, (f + 1) * width, data, from * width);
    }
  }

  Future<PhonemePosteriors> _fallback(AudioClip clip, String reason) {
    stats.fallbackReason = reason;
    return _wholeClip(clip);
  }

  @override
  void cancel() {
    _cancelled = true;
    _pendingCuts.clear();
  }
}

class _Chunk {
  _Chunk(
    this.start,
    this.end,
    this.lo,
    this.hi, {
    required this.last,
    this.filled = false,
  });

  /// Frames kept: `[start, end)` in samples (to the clip's end when [last]).
  final int start, end;

  /// Audio the model saw.
  final int lo, hi;
  bool last;

  /// A pause filled from the piece before it (no model run).
  final bool filled;
  late Future<ChunkPosteriors?> result;
  bool done = false;
}

/// Growable float buffer (amortised doubling).
class _SampleBuffer {
  Float32List _data = Float32List(16000 * 8);
  int length = 0;

  void add(Float32List samples) {
    final needed = length + samples.length;
    if (needed > _data.length) {
      final grown = Float32List(math.max(needed, _data.length * 2))
        ..setRange(0, length, _data);
      _data = grown;
    }
    _data.setRange(length, needed, samples);
    length = needed;
  }

  Float32List copy(int from, int to) =>
      Float32List.fromList(Float32List.sublistView(_data, from, to));
}
