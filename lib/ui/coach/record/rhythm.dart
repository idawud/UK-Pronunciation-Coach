import '../../../core/models/segment.dart';

/// Equal slices of each reading's timeline compared for speech or silence.
const int _slots = 20;

/// Seconds per syllable in the model estimate, before the rate scaling.
const double _secondsPerSyllable = 0.25;

/// Silence after a comma-like mark, and after a full stop, in the model estimate.
const double _commaPauseSeconds = 0.25;
const double _sentencePauseSeconds = 0.6;

/// Rhythm match from 0 to 100 between a reading and a reference, both as speech
/// regions with VAD padding removed (see `speechRegions`).
///
/// Half the score is the ratio of total durations (shorter over longer). The other half
/// is how often the two agree on speech versus silence across 20 equal slices of their
/// own timelines, which places the pauses. Identical readings score 100. Empty or
/// zero-length input scores 0. Never throws.
///
/// The reference is an estimate ([estimateReference]), so the score is a guide, not a
/// measurement.
double rhythmScore(List<Segment> user, List<Segment> reference) {
  final u = _regions(user);
  final r = _regions(reference);
  if (u.isEmpty || r.isEmpty) return 0;
  final uOrigin = u.first.start.inMicroseconds;
  final rOrigin = r.first.start.inMicroseconds;
  final uSpan = u.last.end.inMicroseconds - uOrigin;
  final rSpan = r.last.end.inMicroseconds - rOrigin;
  if (uSpan <= 0 || rSpan <= 0) return 0;

  final duration = uSpan < rSpan ? uSpan / rSpan : rSpan / uSpan;
  var agree = 0;
  for (var i = 0; i < _slots; i++) {
    final t = (i + 0.5) / _slots;
    final userSpeaks = _speaking(u, uOrigin + t * uSpan);
    final refSpeaks = _speaking(r, rOrigin + t * rSpan);
    if (userSpeaks == refSpeaks) agree++;
  }
  final shape = agree / _slots;

  final score = 100 * (0.5 * duration + 0.5 * shape);
  if (score < 0) return 0;
  if (score > 100) return 100;
  return score;
}

/// Estimated speech regions for [text] read at [rate] (1.0 normal, 0.6 slow): about
/// 0.25 s per syllable, with a short pause at commas and a longer one at full stops,
/// stops and question or exclamation marks. Words between marks form one region.
///
/// Labelled as an estimate wherever it is shown; it is not measured from a recording.
List<Segment> estimateReference(String text, {double rate = 1.0}) {
  final speed = rate > 0 ? rate : 1.0;
  final tokens = RegExp(r"[A-Za-z0-9'’]+|[,.;:!?]").allMatches(text);
  final regions = <Segment>[];
  var at = Duration.zero;
  Duration? runStart;
  for (final match in tokens) {
    final token = match.group(0)!;
    if (_isMark(token)) {
      if (runStart != null) {
        regions.add(Segment(start: runStart, end: at));
        runStart = null;
      }
      final pause = token == '.' || token == '!' || token == '?'
          ? _sentencePauseSeconds
          : _commaPauseSeconds;
      at += _scaled(pause, speed);
    } else {
      runStart ??= at;
      at += _scaled(_syllables(token) * _secondsPerSyllable, speed);
    }
  }
  if (runStart != null) regions.add(Segment(start: runStart, end: at));
  return regions;
}

/// Sorted copy of [segments] without empty or inverted regions.
List<Segment> _regions(List<Segment> segments) {
  final out = [
    for (final s in segments)
      if (s.end > s.start) s,
  ];
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// True when [microseconds] falls inside one of the sorted [regions].
bool _speaking(List<Segment> regions, double microseconds) {
  for (final s in regions) {
    if (s.start.inMicroseconds <= microseconds &&
        microseconds < s.end.inMicroseconds) {
      return true;
    }
  }
  return false;
}

bool _isMark(String token) => token.length == 1 && '.,;:!?'.contains(token);

Duration _scaled(double seconds, double rate) => Duration(
  microseconds: (seconds / rate * Duration.microsecondsPerSecond).round(),
);

/// Rough syllable count from vowel groups, with a silent final "e" removed. Never
/// below one.
int _syllables(String word) {
  final w = word.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
  if (w.isEmpty) return 1;
  var groups = RegExp('[aeiouy]+').allMatches(w).length;
  if (w.length > 2 && w.endsWith('e') && !w.endsWith('le') && groups > 1) {
    groups--;
  }
  return groups < 1 ? 1 : groups;
}
