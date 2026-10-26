import 'dart:math' as math;

/// Samples per model frame (20 ms at 16 kHz): cut points are multiples of it, so a
/// chunk's frames line up with the whole clip's frames.
const int frameSamples = 320;

/// wav2vec2's feature encoder looks 400 samples ahead of each frame start.
const int frameWindowSamples = 400;

/// Number of model frames for [samples] samples (clips shorter than one window are
/// padded to one frame, as `InferenceCore` does).
int framesForSamples(int samples) => samples < frameWindowSamples
    ? 1
    : (samples - frameWindowSamples) ~/ frameSamples + 1;

/// Where live recognition may cut a recording, and how much audio each piece sees.
class LiveChunking {
  /// Creates the settings.
  const LiveChunking({
    this.speechThreshold = 0.5,
    this.minSilence = const Duration(milliseconds: 300),
    this.minChunk = const Duration(seconds: 1),
    this.maxChunk = const Duration(seconds: 12),
    this.forcedCutWindow = const Duration(seconds: 2),
    this.context = const Duration(milliseconds: 160),
    this.sampleRate = 16000,
  });

  /// A voice-activity chunk at or above this probability is speech (A1's threshold).
  final double speechThreshold;

  /// A pause this long after speech allows a cut, half-way into the first
  /// [minSilence] (so at least `minSilence / 2` of silence is on each side).
  final Duration minSilence;

  /// No piece is shorter than this (except the last).
  final Duration minChunk;

  /// A piece with no pause gets cut at its quietest point after this long.
  final Duration maxChunk;

  /// How far back a forced cut looks for the quietest point.
  final Duration forcedCutWindow;

  /// Extra audio the model sees on each side of a piece (frames there are dropped).
  final Duration context;

  /// Samples per second.
  final int sampleRate;

  /// [d] in samples.
  int samples(Duration d) => d.inMicroseconds * sampleRate ~/ 1000000;

  /// [context] in samples, rounded down to whole frames (at least 1 frame, so the
  /// last frame of a piece has its 400-sample window).
  int get contextSamples =>
      math.max(1, samples(context) ~/ frameSamples) * frameSamples;
}

/// Decides cut points in a live recording from its voice-activity probabilities:
/// in a pause that follows speech, or at the quietest point of an over-long piece.
/// Pure logic: feed it every block's sample count and probabilities in order.
class ChunkPlanner {
  /// Creates a planner.
  ChunkPlanner([this.settings = const LiveChunking()]);

  /// Settings.
  final LiveChunking settings;

  final List<double> _probabilities = [];
  int _probabilityChunk = 0;
  int _totalSamples = 0;
  int _lastCut = 0;
  bool _speechSinceCut = false;
  int? _silenceStart;

  /// Samples seen so far.
  int get totalSamples => _totalSamples;

  /// The latest cut (0 before the first).
  int get lastCut => _lastCut;

  /// Whether any voice-activity chunk overlapping `[from, totalSamples)` is speech.
  /// True when there are no probabilities at all (unknown counts as speech). The
  /// last partial chunk (under 32 ms) is never analysed and does not count.
  bool speechFrom(int from) {
    if (_probabilityChunk == 0) return true;
    for (var k = from ~/ _probabilityChunk; k < _probabilities.length; k++) {
      if (_probabilities[k] >= settings.speechThreshold) return true;
    }
    return false;
  }

  /// Adds a block of [sampleCount] samples whose completed voice-activity chunks
  /// have [probabilities] (chunk size [chunkSamples]); returns new cut points, in
  /// samples from the start, each a multiple of [frameSamples].
  List<int> add(
    int sampleCount,
    List<double> probabilities, {
    int chunkSamples = 512,
  }) {
    _totalSamples += sampleCount;
    if (probabilities.isEmpty) return const [];
    _probabilityChunk = chunkSamples;
    final cuts = <int>[];
    final minSilence = settings.samples(settings.minSilence);
    final minChunk = settings.samples(settings.minChunk);
    final maxChunk = settings.samples(settings.maxChunk);
    for (final p in probabilities) {
      final k = _probabilities.length;
      _probabilities.add(p);
      final start = k * chunkSamples;
      final end = start + chunkSamples;
      if (p >= settings.speechThreshold) {
        _speechSinceCut = true;
        _silenceStart = null;
      } else {
        final silence = _silenceStart ??= start;
        if (_speechSinceCut && end - silence >= minSilence) {
          final cut = _frameFloor(silence + minSilence ~/ 2);
          if (cut - _lastCut >= minChunk) {
            _cut(cut, cuts);
            continue;
          }
        }
      }
      if (_speechSinceCut && end - _lastCut >= maxChunk) {
        _cut(_quietestCut(k, chunkSamples), cuts);
      }
    }
    return cuts;
  }

  void _cut(int at, List<int> cuts) {
    if (at <= _lastCut) return;
    cuts.add(at);
    _lastCut = at;
    // A new piece only needs a cut once it holds speech (a forced cut can land
    // before speech that was already seen).
    _speechSinceCut = speechFrom(at);
  }

  /// Centre of the least speech-like chunk in the forced-cut window, as a frame
  /// boundary after the last cut.
  int _quietestCut(int last, int chunkSamples) {
    final window = math.max(
      1,
      settings.samples(settings.forcedCutWindow) ~/ chunkSamples,
    );
    var best = last;
    for (var k = last; k >= 0 && k > last - window; k--) {
      if (k * chunkSamples <= _lastCut) break;
      if (_probabilities[k] < _probabilities[best]) best = k;
    }
    final cut = _frameFloor(best * chunkSamples + chunkSamples ~/ 2);
    return cut > _lastCut ? cut : _frameFloor((last + 1) * chunkSamples);
  }

  static int _frameFloor(int samples) => samples ~/ frameSamples * frameSamples;
}
