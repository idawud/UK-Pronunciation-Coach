import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'phoneme_posteriors.freezed.dart';
part 'phoneme_posteriors.g.dart';

/// Per-frame phoneme log-probabilities from the CTC phoneme model (A2 -> A3).
@freezed
abstract class PhonemePosteriors with _$PhonemePosteriors {
  const PhonemePosteriors._();

  /// - [vocab]: model output symbols (IPA phonemes plus the CTC blank, e.g. `<pad>`),
  ///   read from the model's vocab.json; `vocab[i]` labels column i of every frame.
  /// - [frames]: one entry per [frameMs] of audio; each has `vocab.length` natural-log
  ///   probabilities (log-softmax output, so each frame's exp-sum is ~1).
  /// - [blankIndex]: index of the CTC blank symbol in [vocab].
  /// - [frameMs]: frame hop in milliseconds (20 for wav2vec2).
  /// - [tier]: which model tier produced these posteriors.
  const factory PhonemePosteriors({
    required List<String> vocab,
    @Float32ListListConverter() required List<Float32List> frames,
    @Default(0) int blankIndex,
    @Default(20) int frameMs,
    @Default(ModelTier.full) ModelTier tier,
  }) = _PhonemePosteriors;

  /// Decodes from JSON; frames are nested number lists.
  factory PhonemePosteriors.fromJson(Map<String, dynamic> json) =>
      _$PhonemePosteriorsFromJson(json);

  /// Audio time covered by [frames].
  Duration get duration => Duration(milliseconds: frames.length * frameMs);

  /// Start time of frame [i].
  Duration frameStart(int i) => Duration(milliseconds: i * frameMs);
}

/// JSON converter for `List<Float32List>` as nested number lists.
class Float32ListListConverter
    implements JsonConverter<List<Float32List>, List<dynamic>> {
  /// Creates the converter.
  const Float32ListListConverter();

  @override
  List<Float32List> fromJson(List<dynamic> json) => [
    for (final row in json)
      Float32List.fromList([
        for (final v in row as List<dynamic>) (v as num).toDouble(),
      ]),
  ];

  @override
  List<dynamic> toJson(List<Float32List> object) => [
    for (final row in object) List<double>.from(row),
  ];
}
