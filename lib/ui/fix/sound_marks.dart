import '../../core/models/models.dart';

/// What went wrong with one expected sound (from `PhonemeResult.heard`, see A3).
enum SoundIssue {
  /// Said as expected, or could not be judged.
  ok,

  /// Another sound was heard instead (`heard` is that sound).
  substituted,

  /// The sound was left out (`heard == ''`).
  dropped,

  /// The vowel was followed by an r British English does not sound
  /// (`heard == expected + 'ɹ'`).
  addedR,
}

/// Classifies [p] by its `heard` field.
SoundIssue soundIssue(PhonemeResult p) {
  final heard = p.heard;
  if (heard == null || heard == p.expected) return SoundIssue.ok;
  if (heard.isEmpty) return SoundIssue.dropped;
  if (heard.length > p.expected.length && heard.startsWith(p.expected)) {
    final rest = heard.substring(p.expected.length);
    if (rest == 'ɹ' || rest == 'r') return SoundIssue.addedR;
  }
  return SoundIssue.substituted;
}

/// Expected pronunciation of [word] between slashes, with `ˈ` before primary-stressed
/// and `ˌ` before secondary-stressed sounds, e.g. `/θˈɜːzdeɪ/`.
String expectedIpa(WordSpec word) {
  final b = StringBuffer('/');
  for (final p in word.phonemes) {
    if (p.stress == 1) b.write('ˈ');
    if (p.stress == 2) b.write('ˌ');
    b.write(p.ipa);
  }
  b.write('/');
  return b.toString();
}

/// Expected pronunciation from scored [phonemes] (no stress marks), e.g. `/θɜːzdeɪ/`.
String expectedIpaOf(List<PhonemeResult> phonemes) =>
    '/${phonemes.map((p) => p.expected).join()}/';

/// What the model heard for [phonemes]: each sound replaced by its `heard` value,
/// dropped sounds left out, e.g. `/tɜːzdeɪ/`.
String heardIpa(List<PhonemeResult> phonemes) {
  final b = StringBuffer('/');
  for (final p in phonemes) {
    b.write(soundIssue(p) == SoundIssue.ok ? p.expected : p.heard);
  }
  b.write('/');
  return b.toString();
}

/// Whether any sound of [phonemes] was heard differently.
bool hasSoundIssues(List<PhonemeResult> phonemes) =>
    phonemes.any((p) => soundIssue(p) != SoundIssue.ok);

/// The sound to work on first: the first one heard differently, else the
/// lowest-scoring one under 60, else null.
PhonemeResult? worstSound(List<PhonemeResult> phonemes) {
  for (final p in phonemes) {
    if (soundIssue(p) != SoundIssue.ok) return p;
  }
  PhonemeResult? low;
  for (final p in phonemes) {
    if (p.score < WordStatus.defaultClose &&
        (low == null || p.score < low.score)) {
      low = p;
    }
  }
  return low;
}
