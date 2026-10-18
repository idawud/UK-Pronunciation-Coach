// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'segment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Segment _$SegmentFromJson(Map<String, dynamic> json) => _Segment(
  start: Duration(microseconds: (json['start'] as num).toInt()),
  end: Duration(microseconds: (json['end'] as num).toInt()),
);

Map<String, dynamic> _$SegmentToJson(_Segment instance) => <String, dynamic>{
  'start': instance.start.inMicroseconds,
  'end': instance.end.inMicroseconds,
};
