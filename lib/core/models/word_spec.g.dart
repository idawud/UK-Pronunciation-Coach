// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_spec.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WordSpec _$WordSpecFromJson(Map<String, dynamic> json) => _WordSpec(
  text: json['text'] as String,
  index: (json['index'] as num).toInt(),
  phonemes:
      (json['phonemes'] as List<dynamic>?)
          ?.map((e) => PhonemeSpec.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <PhonemeSpec>[],
  scorable: json['scorable'] as bool? ?? true,
  offset: (json['offset'] as num?)?.toInt(),
);

Map<String, dynamic> _$WordSpecToJson(_WordSpec instance) => <String, dynamic>{
  'text': instance.text,
  'index': instance.index,
  'phonemes': instance.phonemes.map((e) => e.toJson()).toList(),
  'scorable': instance.scorable,
  'offset': instance.offset,
};
