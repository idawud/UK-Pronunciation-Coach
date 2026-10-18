import 'package:freezed_annotation/freezed_annotation.dart';

part 'segment.freezed.dart';
part 'segment.g.dart';

/// A region of speech inside a clip, measured from the start of the clip.
@freezed
abstract class Segment with _$Segment {
  const Segment._();

  /// [start] < [end]; both within the clip.
  const factory Segment({required Duration start, required Duration end}) =
      _Segment;

  /// Decodes from JSON (microseconds).
  factory Segment.fromJson(Map<String, dynamic> json) =>
      _$SegmentFromJson(json);

  /// Length of the segment.
  Duration get duration => end - start;
}
