import 'package:freezed_annotation/freezed_annotation.dart';

part 'practice_session.freezed.dart';
part 'practice_session.g.dart';

/// A stretch of practice time, logged for the daily goal and streak (C3 logs, C2 stores).
@freezed
abstract class PracticeSession with _$PracticeSession {
  /// [start] is when practice began; [duration] how long it lasted.
  const factory PracticeSession({
    required DateTime start,
    required Duration duration,
  }) = _PracticeSession;

  /// Decodes from JSON.
  factory PracticeSession.fromJson(Map<String, dynamic> json) =>
      _$PracticeSessionFromJson(json);
}
