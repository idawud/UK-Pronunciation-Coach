import 'dart:math' as math;
import 'dart:typed_data';

import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

import 'espeak_vocab.dart';

/// Builds synthetic CTC posteriors frame by frame where the right answer is known.
class Synth {
  /// Creates a builder over [vocab] (default: the real model vocab).
  Synth({this.vocab = espeakVocab, this.peak = 0.9, this.blankSymbol = '<pad>'})
    : _mapper = PhonemeMapper(ModelVocab(vocab, vocab.indexOf(blankSymbol)));

  /// Model symbols.
  final List<String> vocab;

  /// Probability of each frame's target symbol.
  final double peak;

  /// Blank symbol.
  final String blankSymbol;

  final PhonemeMapper _mapper;
  final List<int> _ids = [];

  /// Frames so far.
  int get length => _ids.length;

  /// Model symbol used for British phoneme [ipa] (its best accepted symbol).
  String symbolFor(String ipa) => vocab[_mapper.unitsFor(ipa).first.ids.first];

  /// [n] blank frames.
  void blank(int n) {
    for (var i = 0; i < n; i++) {
      _ids.add(vocab.indexOf(blankSymbol));
    }
  }

  /// [n] frames of model symbol [symbol].
  void phone(String symbol, [int n = 4]) {
    final id = vocab.indexOf(symbol);
    if (id < 0) throw ArgumentError('$symbol not in vocab');
    for (var i = 0; i < n; i++) {
      _ids.add(id);
    }
  }

  /// Says [word]: each phoneme for [frames] frames (with [blanksBetween] blank
  /// frames after each, like a peaky CTC model), then [gap] blank frames.
  /// [subs] replaces phoneme i with a model symbol ('' drops it).
  void say(
    WordSpec word, {
    Map<int, String> subs = const {},
    int frames = 4,
    int blanksBetween = 0,
    int gap = 2,
  }) {
    for (var i = 0; i < word.phonemes.length; i++) {
      final sym = subs[i] ?? symbolFor(word.phonemes[i].ipa);
      if (sym.isEmpty) {
        blank(frames);
      } else {
        phone(sym, frames);
      }
      blank(blanksBetween);
    }
    blank(gap);
  }

  /// The posteriors.
  PhonemePosteriors build({ModelTier tier = ModelTier.full}) {
    final hi = math.log(peak);
    final lo = math.log((1 - peak) / (vocab.length - 1));
    return PhonemePosteriors(
      vocab: vocab,
      blankIndex: vocab.indexOf(blankSymbol),
      tier: tier,
      frames: [
        for (final id in _ids)
          Float32List(vocab.length)
            ..fillRange(0, vocab.length, lo)
            ..[id] = hi,
      ],
    );
  }
}

/// One speech segment covering frames `[from, to)` of 20 ms.
Segment frameSegment(int from, int to) => Segment(
  start: Duration(milliseconds: from * 20),
  end: Duration(milliseconds: to * 20),
);
