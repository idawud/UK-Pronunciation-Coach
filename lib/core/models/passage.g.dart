// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'passage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Passage _$PassageFromJson(Map<String, dynamic> json) => _Passage(
  id: json['id'] as String,
  level: (json['level'] as num).toInt(),
  title: json['title'] as String,
  text: json['text'] as String,
  words: (json['words'] as List<dynamic>)
      .map((e) => WordSpec.fromJson(e as Map<String, dynamic>))
      .toList(),
  soundTags:
      (json['soundTags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
);

Map<String, dynamic> _$PassageToJson(_Passage instance) => <String, dynamic>{
  'id': instance.id,
  'level': instance.level,
  'title': instance.title,
  'text': instance.text,
  'words': instance.words.map((e) => e.toJson()).toList(),
  'soundTags': instance.soundTags,
};
