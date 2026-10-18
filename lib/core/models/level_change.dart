import 'package:freezed_annotation/freezed_annotation.dart';

part 'level_change.freezed.dart';
part 'level_change.g.dart';

/// A change of level made by the practice engine (C3), shown on Results and Progress.
@freezed
abstract class LevelChange with _$LevelChange {
  const LevelChange._();

  /// - [from], [to]: levels 1-6, different from each other.
  /// - [reason]: one short sentence for the user, e.g.
  ///   "Three passages in a row at 85 or more: welcome to level 4."
  /// - [at]: when it happened.
  const factory LevelChange({
    required int from,
    required int to,
    required String reason,
    required DateTime at,
  }) = _LevelChange;

  /// Decodes from JSON.
  factory LevelChange.fromJson(Map<String, dynamic> json) =>
      _$LevelChangeFromJson(json);

  /// True when moving up.
  bool get isUp => to > from;
}
