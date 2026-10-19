import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/models/segment.dart';
import 'signal.dart';
import 'wav.dart';

/// A stateful speech detector that scores fixed-size chunks of 16 kHz audio.
abstract interface class SpeechProbabilityModel {
  /// Samples per chunk (512 = 32 ms for Silero VAD).
  int get chunkSamples;

  /// Probability (0-1) that [chunk] (exactly [chunkSamples] samples in [-1, 1])
  /// contains speech. Updates the model's internal state.
  double process(Float32List chunk);

  /// Clears the internal state before a new stream.
  void reset();

  /// Frees native resources. The model must not be used afterwards.
  void close();
}

/// Creates detectors: one long-lived streaming model, and whole-clip analysis.
abstract interface class VadBackend {
  /// Short name for logs and the handoff ("silero", "energy").
  String get name;

  /// A fresh streaming model. The caller closes it.
  SpeechProbabilityModel open();

  /// Per-chunk speech probabilities for a whole clip, chunk size
  /// [chunkSamples]. May run off the main isolate.
  Future<List<double>> analyse(Float32List samples);

  /// Samples per chunk of [open]'s model and of [analyse]'s output.
  int get chunkSamples;
}

/// Runs [model] over [samples] chunk by chunk (the last partial chunk is
/// zero-padded) after resetting it.
List<double> probabilitiesOf(
  SpeechProbabilityModel model,
  Float32List samples,
) {
  model.reset();
  final n = model.chunkSamples;
  final out = <double>[];
  for (var i = 0; i < samples.length; i += n) {
    final end = math.min(i + n, samples.length);
    final chunk = end - i == n
        ? Float32List.sublistView(samples, i, end)
        : (Float32List(n)..setRange(0, end - i, samples, i));
    out.add(model.process(chunk));
  }
  return out;
}

/// Splits a stream of arbitrary-size sample blocks into the model's chunks.
class ChunkedVad {
  /// Wraps [model].
  ChunkedVad(this.model) : _buffer = Float32List(model.chunkSamples);

  /// The detector.
  final SpeechProbabilityModel model;
  final Float32List _buffer;
  int _filled = 0;

  /// Probabilities so far, one per chunk.
  final List<double> probabilities = [];

  /// Adds [samples]; returns the probabilities of the chunks they completed.
  List<double> add(Float32List samples) {
    final out = <double>[];
    var i = 0;
    while (i < samples.length) {
      final take = math.min(_buffer.length - _filled, samples.length - i);
      _buffer.setRange(_filled, _filled + take, samples, i);
      _filled += take;
      i += take;
      if (_filled == _buffer.length) {
        out.add(model.process(_buffer));
        _filled = 0;
      }
    }
    probabilities.addAll(out);
    return out;
  }

  /// Scores the last partial chunk (zero-padded), if any.
  List<double> flush() {
    if (_filled == 0) return const [];
    _buffer.fillRange(_filled, _buffer.length, 0);
    _filled = 0;
    final p = model.process(_buffer);
    probabilities.add(p);
    return [p];
  }

  /// Resets the model and forgets everything.
  void reset() {
    model.reset();
    _filled = 0;
    probabilities.clear();
  }
}

/// Settings for turning chunk probabilities into speech.
class VadSettings {
  /// Defaults follow Silero's `get_speech_timestamps`, with the app's 150 ms pad.
  const VadSettings({
    this.threshold = 0.5,
    this.negThreshold = 0.35,
    this.minSpeech = const Duration(milliseconds: 250),
    this.minSilence = const Duration(milliseconds: 100),
    this.pad = const Duration(milliseconds: 150),
    this.silenceAfterSpeech = const Duration(seconds: 2),
  });

  /// A chunk at or above this starts (or continues) speech.
  final double threshold;

  /// A chunk below this counts as silence.
  final double negThreshold;

  /// Shorter speech regions (clicks, coughs) are dropped.
  final Duration minSpeech;

  /// Shorter pauses do not split a region.
  final Duration minSilence;

  /// Padding added to both ends of each region.
  final Duration pad;

  /// Silence after speech that fires `silenceDetected`.
  final Duration silenceAfterSpeech;
}

/// Speech regions from per-chunk [probabilities] (chunks of [chunkSamples] at
/// [sampleRate]): hysteresis between [VadSettings.threshold] and
/// [VadSettings.negThreshold], drop regions shorter than [VadSettings.minSpeech],
/// pad by [VadSettings.pad], merge overlaps, clamp to [clipDuration], sorted.
List<Segment> speechSegmentsFromProbabilities(
  List<double> probabilities, {
  required Duration clipDuration,
  int chunkSamples = 512,
  int sampleRate = recordingSampleRate,
  VadSettings settings = const VadSettings(),
}) {
  Duration at(int chunk) => durationOfSamples(chunk * chunkSamples, sampleRate);
  final raw = <(Duration, Duration)>[];
  var triggered = false;
  var start = Duration.zero;
  Duration? silenceStart;
  void close(Duration end) {
    if (end - start >= settings.minSpeech) raw.add((start, end));
    triggered = false;
    silenceStart = null;
  }

  for (var i = 0; i < probabilities.length; i++) {
    final p = probabilities[i];
    final t = at(i);
    if (p >= settings.threshold) {
      silenceStart = null;
      if (!triggered) {
        triggered = true;
        start = t;
      }
      continue;
    }
    if (triggered && p < settings.negThreshold) {
      silenceStart ??= t;
      if (at(i + 1) - silenceStart! >= settings.minSilence) {
        close(silenceStart!);
      }
    }
  }
  if (triggered) close(silenceStart ?? at(probabilities.length));

  final merged = <Segment>[];
  for (final (s, e) in raw) {
    var ps = s - settings.pad;
    var pe = e + settings.pad;
    if (ps < Duration.zero) ps = Duration.zero;
    if (pe > clipDuration) pe = clipDuration;
    if (ps >= pe) continue;
    if (merged.isNotEmpty && ps <= merged.last.end) {
      final last = merged.removeLast();
      merged.add(
        Segment(start: last.start, end: pe > last.end ? pe : last.end),
      );
    } else {
      merged.add(Segment(start: ps, end: pe));
    }
  }
  return merged;
}

/// Fires once, after [VadSettings.silenceAfterSpeech] of silence that follows at
/// least [VadSettings.minSpeech] of speech. Feed it one probability per chunk.
class SilenceTimer {
  /// Creates a timer for chunks of [chunkSamples] at [sampleRate].
  SilenceTimer({
    this.settings = const VadSettings(),
    int chunkSamples = 512,
    int sampleRate = recordingSampleRate,
  }) : _chunkUs = chunkSamples * 1000000 ~/ sampleRate;

  /// Thresholds and durations.
  final VadSettings settings;
  final int _chunkUs;
  int _speechUs = 0;
  int _silenceUs = 0;
  bool _fired = false;

  /// True once enough speech has been heard to start the silence count.
  bool get heardSpeech => _speechUs >= settings.minSpeech.inMicroseconds;

  /// True after it has fired (it fires once per [reset]).
  bool get fired => _fired;

  /// Adds one chunk's probability; returns true exactly when the timer fires.
  bool add(double p) {
    if (_fired) return false;
    if (p >= settings.threshold) {
      _speechUs += _chunkUs;
      _silenceUs = 0;
      return false;
    }
    if (p >= settings.negThreshold || !heardSpeech) {
      // Ambiguous chunk, or no speech yet: the silence count starts over.
      _silenceUs = 0;
      return false;
    }
    _silenceUs += _chunkUs;
    if (_silenceUs >= settings.silenceAfterSpeech.inMicroseconds) {
      _fired = true;
      return true;
    }
    return false;
  }

  /// Starts over for a new recording.
  void reset() {
    _speechUs = 0;
    _silenceUs = 0;
    _fired = false;
  }
}

/// Fallback detector when the Silero model is missing: chunk RMS against an
/// adaptive noise floor. Much cruder than Silero (any loud sound counts as
/// speech), but keeps `silenceDetected` and `speechSegments` working.
class EnergySpeechModel implements SpeechProbabilityModel {
  /// Creates the model.
  EnergySpeechModel({
    this.chunkSamples = 512,
    this.marginDb = 15,
    this.absoluteFloorDbfs = -50,
  });

  @override
  final int chunkSamples;

  /// How far above the noise floor a chunk must be to count as speech.
  final double marginDb;

  /// Chunks quieter than this are never speech.
  final double absoluteFloorDbfs;

  double? _floor;

  @override
  double process(Float32List chunk) {
    final db = rmsDbfs(chunk);
    final f = _floor;
    // Falls fast to quiet chunks, creeps up slowly so long speech does not
    // become the floor.
    _floor = f == null ? db : (db < f ? db : f + 0.02 * (db - f));
    if (db < absoluteFloorDbfs) return 0;
    final floor = math.max(_floor!, -70.0);
    return 1 / (1 + math.exp(-(db - floor - marginDb) / 3));
  }

  @override
  void reset() => _floor = null;

  @override
  void close() {}
}

/// [VadBackend] over [EnergySpeechModel] (pure Dart).
class EnergyVadBackend implements VadBackend {
  /// Creates the backend.
  const EnergyVadBackend();

  @override
  String get name => 'energy';

  @override
  int get chunkSamples => 512;

  @override
  SpeechProbabilityModel open() =>
      EnergySpeechModel(chunkSamples: chunkSamples);

  @override
  Future<List<double>> analyse(Float32List samples) async =>
      probabilitiesOf(open(), samples);
}
