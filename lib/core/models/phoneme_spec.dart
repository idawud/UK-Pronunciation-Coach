import 'package:freezed_annotation/freezed_annotation.dart';

part 'phoneme_spec.freezed.dart';
part 'phoneme_spec.g.dart';

/// One expected British phoneme of a word, e.g. `θ` or `ɜː`.
@freezed
abstract class PhonemeSpec with _$PhonemeSpec {
  /// [ipa] is a single IPA phoneme (length marks included, stress marks excluded).
  /// [stress] is 0 (none), 1 (primary) or 2 (secondary); only vowels carry stress.
  const factory PhonemeSpec({required String ipa, @Default(0) int stress}) =
      _PhonemeSpec;

  /// Decodes from JSON.
  factory PhonemeSpec.fromJson(Map<String, dynamic> json) =>
      _$PhonemeSpecFromJson(json);
}
