import '../models/attempt_result.dart';
import '../models/passage.dart';
import '../models/phoneme_posteriors.dart';
import '../models/segment.dart';
import '../models/word_result.dart';
import '../models/word_spec.dart';

/// Aligns expected phonemes to model posteriors and scores them (A3). Pure Dart and
/// synchronous: no Flutter imports, no I/O. Scoring 200 words takes < 100 ms.
abstract interface class PronunciationScorer {
  /// Scores a reading of [passage].
  ///
  /// - [posteriors]: model output for the whole clip.
  /// - [speech]: VAD speech segments of the clip (from `AudioRecorder.speechSegments`),
  ///   used for pauses and speaking rate.
  /// - [attemptId], [at], [audioPath]: copied into the result; when null, [at] is
  ///   `DateTime.now()` and [attemptId] is derived from it.
  ///
  /// The result has exactly one [WordResult] per passage word, in order, with
  /// `index` equal to the word's index. Words with `scorable == false` get
  /// `WordStatus.notScored` and score 0; words not said get `WordStatus.missed` and
  /// score 0. Every score is 0-100; `overall = round(0.7 * accuracy + 0.3 * fluency)`;
  /// `tier` is copied from [posteriors].
  AttemptResult score(
    Passage passage,
    PhonemePosteriors posteriors,
    List<Segment> speech, {
    String? attemptId,
    DateTime? at,
    String? audioPath,
  });

  /// Scores a single-word retry: [posteriors] cover a clip of just [word].
  /// The result's `index` and `text` come from [word].
  WordResult scoreWord(WordSpec word, PhonemePosteriors posteriors);
}
