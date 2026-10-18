import 'package:freezed_annotation/freezed_annotation.dart';

part 'phoneme_result.freezed.dart';
part 'phoneme_result.g.dart';

/// Score for one expected phoneme of a word (A3).
@freezed
abstract class PhonemeResult with _$PhonemeResult {
  /// - [expected]: expected IPA phoneme (as in `PhonemeSpec.ipa`).
  /// - [heard]: the top competing phoneme the model heard instead; equals [expected] or
  ///   is null when it was said correctly or could not be judged.
  /// - [score]: 0-100 goodness of pronunciation.
  /// - [start], [end]: aligned time span inside the clip.
  const factory PhonemeResult({
    required String expected,
    String? heard,
    required int score,
    required Duration start,
    required Duration end,
  }) = _PhonemeResult;

  /// Decodes from JSON.
  factory PhonemeResult.fromJson(Map<String, dynamic> json) =>
      _$PhonemeResultFromJson(json);
}
