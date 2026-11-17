import '../../core/contracts/contracts.dart';
import '../../core/models/models.dart';

/// One piece of speech: [text] spoken at [rate] (see [VoiceService]).
class SpeechSegment {
  /// Creates a segment.
  const SpeechSegment(this.text, this.rate);

  /// The words to say.
  final String text;

  /// Speaking rate: [VoiceService.normalRate] or [VoiceService.slowRate].
  final double rate;

  @override
  bool operator ==(Object other) =>
      other is SpeechSegment && other.text == text && other.rate == rate;

  @override
  int get hashCode => Object.hash(text, rate);

  @override
  String toString() => 'SpeechSegment($text, $rate)';
}

/// The words sorted by [WordResult.index], so playback follows the passage order
/// whatever order the list arrived in.
List<WordResult> _inOrder(List<WordResult> words) =>
    [...words]..sort((a, b) => a.index.compareTo(b.index));

/// Whether [word] has anything to say.
bool _hasText(WordResult word) => word.text.trim().isNotEmpty;

/// The whole passage as one segment at normal speed, words joined by single spaces.
/// Returns an empty list when no word has text.
List<SpeechSegment> fullSentenceSegments(List<WordResult> words) {
  final text = [
    for (final w in _inOrder(words))
      if (_hasText(w)) w.text.trim(),
  ].join(' ');
  if (text.isEmpty) return const [];
  return [SpeechSegment(text, VoiceService.normalRate)];
}

/// The passage in order: good words at normal speed, every other word slowed.
/// Consecutive words at the same rate are merged into one segment. Blank words are
/// skipped.
List<SpeechSegment> stressedSegments(List<WordResult> words) {
  final segments = <SpeechSegment>[];
  var pending = <String>[];
  double? pendingRate;

  void flush() {
    final rate = pendingRate;
    if (pending.isEmpty || rate == null) return;
    segments.add(SpeechSegment(pending.join(' '), rate));
    pending = <String>[];
  }

  for (final w in _inOrder(words)) {
    if (!_hasText(w)) continue;
    final rate = w.status == WordStatus.good
        ? VoiceService.normalRate
        : VoiceService.slowRate;
    if (rate != pendingRate) flush();
    pendingRate = rate;
    pending.add(w.text.trim());
  }
  flush();
  return segments;
}

/// Each word that is not good, in passage order, spoken slowly on its own. Empty when
/// every word is good.
List<SpeechSegment> wrongWordsSegments(List<WordResult> words) => [
  for (final w in _inOrder(words))
    if (w.status != WordStatus.good && _hasText(w))
      SpeechSegment(w.text.trim(), VoiceService.slowRate),
];
