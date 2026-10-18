// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'minimal_pair.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MinimalPair _$MinimalPairFromJson(Map<String, dynamic> json) => _MinimalPair(
  contrast: json['contrast'] as String,
  wordA: json['wordA'] as String,
  wordB: json['wordB'] as String,
  phonemesA:
      (json['phonemesA'] as List<dynamic>?)
          ?.map((e) => PhonemeSpec.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <PhonemeSpec>[],
  phonemesB:
      (json['phonemesB'] as List<dynamic>?)
          ?.map((e) => PhonemeSpec.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <PhonemeSpec>[],
);

Map<String, dynamic> _$MinimalPairToJson(_MinimalPair instance) =>
    <String, dynamic>{
      'contrast': instance.contrast,
      'wordA': instance.wordA,
      'wordB': instance.wordB,
      'phonemesA': instance.phonemesA.map((e) => e.toJson()).toList(),
      'phonemesB': instance.phonemesB.map((e) => e.toJson()).toList(),
    };
