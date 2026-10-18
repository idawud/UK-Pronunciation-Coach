import 'package:freezed_annotation/freezed_annotation.dart';

part 'sound_stat.freezed.dart';
part 'sound_stat.g.dart';

/// Rolling accuracy for one British phoneme across all attempts (C2 stores, C3/U1/U4 read).
@freezed
abstract class SoundStat with _$SoundStat {
  const SoundStat._();

  /// Default smoothing factor for [update].
  static const double defaultAlpha = 0.3;

  /// - [ipa]: the phoneme.
  /// - [accuracy]: exponential moving average of phoneme scores, 0-100.
  /// - [attempts]: number of scored occurrences folded in.
  /// - [lastPractised]: time of the latest occurrence.
  const factory SoundStat({
    required String ipa,
    required double accuracy,
    required int attempts,
    required DateTime lastPractised,
  }) = _SoundStat;

  /// Decodes from JSON.
  factory SoundStat.fromJson(Map<String, dynamic> json) =>
      _$SoundStatFromJson(json);

  /// First observation of [ipa]: accuracy equals [score].
  factory SoundStat.first(String ipa, int score, DateTime at) => SoundStat(
    ipa: ipa,
    accuracy: score.toDouble(),
    attempts: 1,
    lastPractised: at,
  );

  /// Folds a new 0-100 [score] in with an exponential moving average:
  /// `accuracy = alpha * score + (1 - alpha) * accuracy`. Shared rule for C2 and fakes.
  SoundStat update(int score, DateTime at, {double alpha = defaultAlpha}) =>
      copyWith(
        accuracy: alpha * score + (1 - alpha) * accuracy,
        attempts: attempts + 1,
        lastPractised: at.isAfter(lastPractised) ? at : lastPractised,
      );
}
