import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Output symbols of a CTC phoneme model, read from its Hugging Face `vocab.json`
/// (`{"<pad>": 0, "<s>": 1, ..., "t": 6, ...}`).
class ModelVocab {
  /// Creates a vocab from [symbols] (index = logit column) and the CTC [blankIndex].
  ModelVocab(List<String> symbols, this.blankIndex)
    : symbols = List.unmodifiable(symbols) {
    if (symbols.isEmpty) throw const FormatException('Empty vocab');
    if (blankIndex < 0 || blankIndex >= symbols.length) {
      throw FormatException('Blank index $blankIndex out of range');
    }
  }

  /// Parses `vocab.json`. Indices must be exactly 0..n-1. The blank is `<pad>`
  /// (wav2vec2's CTC blank, `pad_token_id`), else `<blank>`, `[PAD]` or `_`, else 0.
  factory ModelVocab.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('vocab.json must be an object');
    }
    final symbols = List<String?>.filled(decoded.length, null);
    for (final entry in decoded.entries) {
      final index = entry.value;
      if (index is! int || index < 0 || index >= symbols.length) {
        throw FormatException('Bad index for "${entry.key}": $index');
      }
      if (symbols[index] != null) {
        throw FormatException('Duplicate index $index');
      }
      symbols[index] = entry.key;
    }
    final list = symbols.cast<String>();
    var blank = 0;
    for (final candidate in blankCandidates) {
      final i = list.indexOf(candidate);
      if (i >= 0) {
        blank = i;
        break;
      }
    }
    return ModelVocab(list, blank);
  }

  /// Symbols tried, in order, as the CTC blank.
  static const blankCandidates = ['<pad>', '<blank>', '[PAD]', '_'];

  /// Symbol for each logit column.
  final List<String> symbols;

  /// Column of the CTC blank.
  final int blankIndex;

  /// Number of symbols.
  int get length => symbols.length;
}

/// Applies log-softmax (natural log) in place to each row of row-major
/// `[frames, vocabSize]` [values], so every row's exp-sum becomes 1.
void logSoftmaxRowsInPlace(Float32List values, int vocabSize) {
  _checkRows(values, vocabSize);
  for (var start = 0; start < values.length; start += vocabSize) {
    final end = start + vocabSize;
    var max = double.negativeInfinity;
    for (var i = start; i < end; i++) {
      if (values[i] > max) max = values[i];
    }
    var sum = 0.0;
    for (var i = start; i < end; i++) {
      sum += math.exp(values[i] - max);
    }
    final logSum = max + math.log(sum);
    for (var i = start; i < end; i++) {
      values[i] -= logSum;
    }
  }
}

/// Splits row-major `[frames, vocabSize]` [values] into per-frame views (no copy).
List<Float32List> splitFrames(Float32List values, int vocabSize) {
  _checkRows(values, vocabSize);
  return List<Float32List>.generate(
    values.length ~/ vocabSize,
    (f) => Float32List.sublistView(values, f * vocabSize, (f + 1) * vocabSize),
    growable: false,
  );
}

void _checkRows(Float32List values, int vocabSize) {
  if (vocabSize <= 0 || values.length % vocabSize != 0) {
    throw ArgumentError(
      'length ${values.length} is not a multiple of vocab size $vocabSize',
    );
  }
}

/// Greedy CTC decode (argmax per frame, collapse repeats, drop blanks). For tests and
/// debugging only; scoring uses forced alignment (A3).
List<String> greedyDecode(List<Float32List> frames, ModelVocab vocab) {
  final out = <String>[];
  var previous = -1;
  for (final frame in frames) {
    var best = 0;
    for (var i = 1; i < frame.length; i++) {
      if (frame[i] > frame[best]) best = i;
    }
    if (best != previous && best != vocab.blankIndex) {
      out.add(vocab.symbols[best]);
    }
    previous = best;
  }
  return out;
}
