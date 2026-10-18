import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'word_result.dart';

part 'attempt_result.freezed.dart';
part 'attempt_result.g.dart';

/// One scored reading of a passage (or of a sentence / word retry).
@freezed
abstract class AttemptResult with _$AttemptResult {
  const AttemptResult._();

  /// - [id]: unique id (e.g. a timestamp-based string).
  /// - [passageId]: `Passage.id` that was read.
  /// - [at]: when the attempt finished.
  /// - [overall]: 0-100, `round(0.7 * accuracy + 0.3 * fluency)`.
  /// - [accuracy]: 0-100 from word scores.
  /// - [fluency]: 0-100 from pace, pauses, missed / extra / repeated words.
  /// - [words]: one result per passage word, in passage order.
  /// - [audioPath]: kept recording, or null once deleted (see `UserProfile.keepRecordings`).
  /// - [tier]: model tier used; with [ModelTier.light] the UI shows word scores only.
  const factory AttemptResult({
    required String id,
    required String passageId,
    required DateTime at,
    required int overall,
    required int accuracy,
    required int fluency,
    required List<WordResult> words,
    String? audioPath,
    @Default(ModelTier.full) ModelTier tier,
  }) = _AttemptResult;

  /// Decodes from JSON. [at] is ISO-8601.
  factory AttemptResult.fromJson(Map<String, dynamic> json) =>
      _$AttemptResultFromJson(json);

  /// Words shown in red ([WordStatus.fix] or [WordStatus.missed]), in passage order.
  List<WordResult> get redWords => [
    for (final w in words)
      if (w.status.isRed) w,
  ];
}
