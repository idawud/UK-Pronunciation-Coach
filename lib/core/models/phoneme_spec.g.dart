// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phoneme_spec.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PhonemeSpec _$PhonemeSpecFromJson(Map<String, dynamic> json) => _PhonemeSpec(
  ipa: json['ipa'] as String,
  stress: (json['stress'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$PhonemeSpecToJson(_PhonemeSpec instance) =>
    <String, dynamic>{'ipa': instance.ipa, 'stress': instance.stress};
