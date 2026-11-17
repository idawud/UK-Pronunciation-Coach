import '../../../core/models/segment.dart';

/// Silence longer than this between two speech regions counts as a pause.
const Duration longPause = Duration(milliseconds: 400);

/// Padding the voice-activity detector adds around each speech region. The recorder's
/// `speechSegments` pads every region by 150 ms and merges overlaps, so the real
/// speech is 150 ms shorter at each end and the real silence is 300 ms longer.
const Duration vadPadding = Duration(milliseconds: 150);

/// Pace and pause figures for one reading. These are estimates from a phone microphone;
/// the word count comes from the typed line, not from recognition.
class PaceStats {
  /// Creates the figures.
  const PaceStats({
    required this.speech,
    required this.words,
    required this.pauseCount,
    required this.longestPause,
  });

  /// Time spent speaking (pauses excluded, VAD padding removed).
  final Duration speech;

  /// Words in the typed line.
  final int words;

  /// Silences longer than [longPause] between speech regions.
  final int pauseCount;

  /// Longest silence between speech regions, or zero when there is none.
  final Duration longestPause;

  /// Words per minute over the speaking time, or null when there is no speech or no
  /// words to count.
  double? get wordsPerMinute {
    if (speech == Duration.zero || words == 0) return null;
    return words / (speech.inMicroseconds / Duration.microsecondsPerMinute);
  }
}

/// Turns raw `AudioRecorder.speechSegments` output into speech regions with the VAD
/// padding removed: sorted by start, each region shrunk by [padding] at both ends, and
/// regions that vanish are dropped. Use this before [rhythmScore].
List<Segment> speechRegions(
  List<Segment> segments, {
  Duration padding = vadPadding,
}) {
  final regions = <Segment>[
    for (final s in segments)
      if (s.end - padding > s.start + padding)
        Segment(start: s.start + padding, end: s.end - padding),
  ]..sort((a, b) => a.start.compareTo(b.start));
  return regions;
}

/// Pace and pauses for a reading of [text] whose raw VAD [segments] came from
/// `AudioRecorder.speechSegments`. Pure: no I/O, never throws.
PaceStats paceStats(List<Segment> segments, String text) =>
    paceFromRegions(speechRegions(segments), text);

/// Like [paceStats] but for segments that are already speech regions (padding removed),
/// such as the model estimate from `estimateReference`.
PaceStats paceFromRegions(List<Segment> regions, String text) {
  final sorted = [...regions]..sort((a, b) => a.start.compareTo(b.start));
  var speech = Duration.zero;
  var pauses = 0;
  var longest = Duration.zero;
  for (var i = 0; i < sorted.length; i++) {
    final region = sorted[i];
    if (region.end <= region.start) continue;
    speech += region.duration;
    if (i > 0) {
      final gap = region.start - sorted[i - 1].end;
      if (gap > longest) longest = gap;
      if (gap > longPause) pauses++;
    }
  }
  return PaceStats(
    speech: speech,
    words: countWords(text),
    pauseCount: pauses,
    longestPause: longest,
  );
}

/// Number of words in [text]: runs of letters, digits and apostrophes.
int countWords(String text) =>
    RegExp(r"[A-Za-z0-9'’]+").allMatches(text).length;

/// Plain-language reading of a words-per-minute figure.
String paceHint(double? wordsPerMinute) {
  if (wordsPerMinute == null) return 'No speech heard yet.';
  if (wordsPerMinute < 100) {
    return 'Slower than everyday speech. Fine for practice.';
  }
  if (wordsPerMinute < 160) return 'A natural conversational pace.';
  return 'Quick. Slow down so each sound lands clearly.';
}

/// Plain-language reading of the pause figures.
String pauseHint(PaceStats stats) {
  if (stats.pauseCount == 0) return 'Smooth: no long pauses.';
  if (stats.pauseCount <= 2) {
    return 'A pause or two. Good if they fall at commas or full stops.';
  }
  return 'Many long pauses. Try grouping words into phrases.';
}
