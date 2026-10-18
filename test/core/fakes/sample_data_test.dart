import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';

void main() {
  test('sample passages are levels 1, 3, 5 with valid offsets', () {
    expect(samplePassages.map((p) => p.level), [1, 3, 5]);
    expect(riverPassage.title, 'A walk by the river');
    for (final p in samplePassages) {
      for (final w in p.words) {
        expect(p.text.substring(w.offset!, w.offset! + w.text.length), w.text);
        expect(w.phonemes, isNotEmpty);
        for (final ph in w.phonemes) {
          expect(sampleVocab, contains(ph.ipa), reason: '${w.text}: ${ph.ipa}');
        }
      }
    }
  });

  test('parseIpa reads stress marks', () {
    expect(parseIpa('θ ˈɜː z d ˌeɪ'), [
      const PhonemeSpec(ipa: 'θ'),
      const PhonemeSpec(ipa: 'ɜː', stress: 1),
      const PhonemeSpec(ipa: 'z'),
      const PhonemeSpec(ipa: 'd'),
      const PhonemeSpec(ipa: 'eɪ', stress: 2),
    ]);
  });

  test('buildPassage checks the transcription count', () {
    expect(
      () =>
          buildPassage(id: 'x', level: 1, title: 't', text: 'a b', ipa: ['a']),
      throwsArgumentError,
    );
    final p = buildPassage(
      id: 'x',
      level: 1,
      title: 't',
      text: 'Hi Zork',
      ipa: ['h ˈaɪ', ''],
    );
    expect(p.words[1].scorable, isFalse);
  });

  test('canned river attempt: Thursday, castle and bath are red', () {
    final red = cannedRiverAttempt.redWords.map((w) => w.text);
    expect(red, ['Thursday', 'castle', 'bath']);
    final amber = cannedRiverAttempt.words
        .where((w) => w.status == WordStatus.close)
        .map((w) => w.text);
    expect(amber, ['walked', 'river']);
    expect(cannedRiverAttempt.words[1].phonemes.first.heard, 't');
    expect(
      cannedRiverAttempt.overall,
      (0.7 * cannedRiverAttempt.accuracy + 0.3 * cannedRiverAttempt.fluency)
          .round(),
    );
  });

  test(
    'synthetic posteriors are log-softmax frames with the substitutions',
    () {
      final p = riverPosteriors;
      expect(p.vocab.first, sampleBlank);
      for (final f in p.frames) {
        var sum = 0.0;
        for (final v in f) {
          sum += math.exp(v);
        }
        expect(sum, closeTo(1, 1e-3));
      }
      final layout = syntheticLayout(riverPassage);
      int argmax(int frame) {
        final f = p.frames[frame];
        var best = 0;
        for (var i = 1; i < f.length; i++) {
          if (f[i] > f[best]) best = i;
        }
        return best;
      }

      expect(p.vocab[argmax(layout[1]![0].$1)], 't');
      expect(p.vocab[argmax(layout[1]![1].$1)], 'ɜː');
      expect(p.vocab[argmax(0)], sampleBlank);
      expect(
        () => syntheticPosteriors(
          teaPassage,
          substitutions: {
            0: {0: 'Q'},
          },
        ),
        throwsArgumentError,
      );
    },
  );

  test('missed words get no frames; speech segment is padded', () {
    final full = syntheticPosteriors(riverPassage);
    final missed = syntheticPosteriors(riverPassage, missedWords: {6});
    expect(missed.frames.length, lessThan(full.frames.length));
    final attempt = buildAttempt(
      riverPassage,
      id: 'm',
      at: DateTime(2026),
      missedWords: {6},
    );
    expect(attempt.words[6].status, WordStatus.missed);
    final speech = syntheticSpeech(full).single;
    expect(speech.start, const Duration(milliseconds: 50));
    expect(speech.end, full.duration - const Duration(milliseconds: 50));
  });

  test('unscorable words in buildAttempt are notScored', () {
    final p = buildPassage(
      id: 'x',
      level: 1,
      title: 't',
      text: 'Hi Zork',
      ipa: ['h ˈaɪ', ''],
    );
    final a = buildAttempt(p, id: 'x', at: DateTime(2026));
    expect(a.words[1].status, WordStatus.notScored);
    expect(a.accuracy, a.words[0].score);
  });
}
