import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

import 'support/synth.dart';

const edge = 10;

/// Reads [p] with [Synth.say] per word; [before] runs before word i is said.
({PhonemePosteriors post, List<Segment> speech}) read(
  Passage p, {
  Map<int, Map<int, String>> subs = const {},
  Set<int> missed = const {},
  Map<int, void Function(Synth s)> before = const {},
  int frames = 6,
  int blanksBetween = 0,
  int gap = 3,
  Synth? synth,
}) {
  final s = synth ?? Synth();
  s.blank(edge);
  for (final w in p.words) {
    before[w.index]?.call(s);
    if (missed.contains(w.index) || !w.scorable) continue;
    s.say(
      w,
      subs: subs[w.index] ?? const {},
      frames: frames,
      blanksBetween: blanksBetween,
      gap: gap,
    );
  }
  final end = s.length;
  s.blank(edge);
  return (post: s.build(), speech: [frameSegment(edge - 5, end + 5)]);
}

void main() {
  const scorer = GopPronunciationScorer();
  final p = riverPassage;

  ScoringAnalysis analyse(
    ({PhonemePosteriors post, List<Segment> speech}) r, [
    Passage? passage,
  ]) => scorer.analyse(passage ?? p, r.post, r.speech);

  group('perfect read (real model vocab)', () {
    final r = read(p);
    final a = analyse(r);

    test('every word is good with high accuracy', () {
      for (final w in a.words) {
        expect(w.status, WordStatus.good, reason: w.text);
        expect(w.score, greaterThanOrEqualTo(90), reason: w.text);
        for (final ph in w.phonemes) {
          expect(ph.heard, isNull, reason: '${w.text} ${ph.expected}');
        }
      }
      expect(a.accuracy, greaterThanOrEqualTo(90));
      expect(a.alignment, isNotNull);
    });

    test('fluency is high at a normal pace', () {
      expect(a.fluency.wordsPerMinute, inInclusiveRange(130, 170));
      expect(a.fluency.rateScore, 100);
      expect(a.fluency.pauses, isEmpty);
      expect(a.fluency.missedWords, 0);
      expect(a.extras, isEmpty);
      expect(a.fluency.score, greaterThanOrEqualTo(95));
      expect(a.overall, (0.7 * a.accuracy + 0.3 * a.fluency.score).round());
    });

    test('phoneme and word times follow the audio', () {
      final first = a.words.first.phonemes;
      expect(first[0].start, const Duration(milliseconds: edge * 20));
      expect(first[0].end, const Duration(milliseconds: (edge + 6) * 20));
      expect(first[1].start, first[0].end);
      final second = a.words[1].phonemes.first;
      expect(second.start, const Duration(milliseconds: (edge + 12 + 3) * 20));
    });

    test('score() wraps the analysis', () {
      final at = DateTime(2026, 10, 18);
      final res = scorer.score(p, r.post, r.speech, attemptId: 'x', at: at);
      expect(res.id, 'x');
      expect(res.at, at);
      expect(res.accuracy, a.accuracy);
      expect(res.fluency, a.fluency.score);
      expect(res.overall, a.overall);
      expect(res.words, a.words);
      expect(res.tier, ModelTier.full);
    });
  });

  test('a peaky CTC read (one-frame spikes between blanks) is good', () {
    final a = analyse(read(p, frames: 1, blanksBetween: 3));
    expect(a.words.where((w) => w.status != WordStatus.good), isEmpty);
    expect(a.accuracy, greaterThanOrEqualTo(90));
  });

  test('a substituted phoneme lowers the word and reports heard', () {
    // A3's mapping only: I2-eval's extraAccepted lets a schwa accept `æ`, and in
    // this synthetic read the substituted `æ` of "bath" is then aligned to a
    // neighbouring schwa, which moves the heard attribution (the word is still red).
    const a3Mapping = GopPronunciationScorer(
      config: ScoringConfig(extraAccepted: {}),
    );
    final rGood = read(p);
    final good = a3Mapping.analyse(p, rGood.post, rGood.speech);
    final rSub = read(
      p,
      subs: {
        1: {0: 't'},
        21: {1: 'æ', 2: 'f'},
      },
    );
    final a = a3Mapping.analyse(p, rSub.post, rSub.speech);
    final thursday = a.words[1];
    expect(thursday.phonemes.first.heard, 't');
    expect(thursday.phonemes.first.score, lessThan(20));
    expect(thursday.score, lessThan(good.words[1].score));
    expect(thursday.phonemes[1].heard, isNull);
    final bath = a.words[21];
    expect(bath.status, WordStatus.fix);
    expect(bath.phonemes.first.heard, isNull);
    expect(
      bath.phonemes.skip(1).map((ph) => ph.heard),
      everyElement(isNotNull),
    );
    expect(a.accuracy, lessThan(good.accuracy));
    // The neighbours stay good.
    expect(a.words[0].status, WordStatus.good);
    expect(a.words[2].status, WordStatus.good);
    // Tips exist for what was heard.
    const tips = TableTips();
    expect(tips.tipFor('θ', thursday.phonemes.first.heard), isNotNull);
    expect(tips.tipFor('ɑː', bath.phonemes[1].heard), contains('jaw'));
  });

  group('missed words', () {
    test('a word not said is missed and costs fluency', () {
      final a = analyse(read(p, missed: {6}));
      expect(a.words[6].status, WordStatus.missed);
      expect(a.words[6].score, 0);
      expect(a.words[6].phonemes, isEmpty);
      expect(a.words[5].status, WordStatus.good);
      expect(a.words[7].status, WordStatus.good);
      expect(a.fluency.missedWords, 1);
      expect(a.fluency.continuityScore, lessThan(100));
    });

    test('first, last and consecutive words can be missed', () {
      final a = analyse(read(p, missed: {0, 12, 13, 26}));
      for (final i in [0, 12, 13, 26]) {
        expect(a.words[i].status, WordStatus.missed, reason: '$i');
      }
      expect(
        a.words.where((w) => w.status == WordStatus.good),
        hasLength(p.words.length - 4),
      );
    });

    test('silence: every word missed, scores 0', () {
      final s = Synth()..blank(200);
      final res = scorer.score(p, s.build(), const []);
      expect(res.words.every((w) => w.status == WordStatus.missed), isTrue);
      expect(res.accuracy, 0);
      expect(res.fluency, 0);
      expect(res.overall, 0);
    });

    test('no frames: every word missed', () {
      final res = scorer.score(p, Synth().build(), const []);
      expect(res.words.every((w) => w.status == WordStatus.missed), isTrue);
    });

    test('weak speech that the aligner keeps is still missed', () {
      // A forced alignment (huge skip cost) through silence: the speech check
      // marks the word missed.
      const forced = GopPronunciationScorer(
        config: ScoringConfig(skipWordPenalty: 1e9),
      );
      final post = (Synth()..blank(40)).build();
      final a = forced.analyse(p.slice(1, 2), post, const []);
      expect(a.alignment!.skipped, [false]);
      expect(a.words.single.status, WordStatus.missed);
    });
  });

  test('a dropped sound is heard as empty', () {
    final a = analyse(
      read(
        p,
        subs: {
          3: {3: ''},
        },
      ),
    );
    final walked = a.words[3];
    expect(walked.status, isNot(WordStatus.missed));
    expect(walked.phonemes[3].heard, '');
    expect(walked.phonemes[3].score, scorer.config.droppedScore);
    expect(const TableTips().tipFor('t', ''), isNotNull);
  });

  group('pauses', () {
    test('a long pause mid-sentence costs fluency', () {
      final good = analyse(read(p));
      final a = analyse(read(p, before: {4: (s) => s.blank(100)}));
      expect(a.fluency.pauses, hasLength(1));
      final pause = a.fluency.pauses.single;
      expect(pause.afterWord, 3);
      expect(pause.ms, greaterThanOrEqualTo(2000));
      expect(pause.atPunctuation, isFalse);
      expect(pause.penalty, greaterThan(20));
      expect(a.fluency.pauseScore, lessThan(80));
      expect(a.fluency.score, lessThan(good.fluency.score));
      // Pronunciation is unaffected.
      expect(a.accuracy, good.accuracy);
    });

    test('a short pause at a full stop is free', () {
      final a = analyse(read(p, before: {7: (s) => s.blank(50)}));
      expect(a.fluency.pauses.single.atPunctuation, isTrue);
      expect(a.fluency.pauses.single.penalty, 0);
      expect(a.fluency.pauseScore, 100);
    });

    test('a VAD silence inside a word gap counts as a pause', () {
      final r = read(p, before: {4: (s) => s.blank(17)});
      // Word 4 starts after a 20-frame gap; VAD splits there.
      final a0 = analyse(r);
      expect(a0.fluency.pauses, isEmpty);
      final start4 = a0.words[4].phonemes.first.start.inMilliseconds ~/ 20;
      final split = [
        frameSegment(edge - 5, start4 - 16),
        frameSegment(start4 - 2, r.post.frames.length - 5),
      ];
      final a = scorer.analyse(p, r.post, split);
      expect(a.fluency.pauses, hasLength(1));
    });
  });

  group('extra and repeated words', () {
    test('an inserted word is counted as extra', () {
      final a = analyse(
        read(
          p,
          before: {
            3: (s) => s
              ..phone('s', 5)
              ..phone('ʌ', 5)
              ..phone('n', 5)
              ..blank(3),
          },
        ),
      );
      expect(a.extras, hasLength(1));
      expect(a.extras.single.phones, ['s', 'ʌ', 'n']);
      expect(a.extras.single.words, 1);
      expect(a.extras.single.repeatOf, isNull);
      expect(a.fluency.extraWords, 1);
      expect(a.words.every((w) => w.status == WordStatus.good), isTrue);
    });

    test('a repeated word is counted as a repeat (peaky CTC output)', () {
      final a = analyse(
        read(
          p,
          frames: 1,
          blanksBetween: 4,
          before: {
            4: (s) => s.say(p.words[3], frames: 1, blanksBetween: 4, gap: 3),
          },
        ),
      );
      expect(a.extras, hasLength(1));
      expect(a.extras.single.repeatOf, 3);
      expect(a.extras.single.words, 0);
      expect(a.fluency.repeatedWords, 1);
      expect(a.fluency.extraWords, 0);
      expect(a.fluency.continuityScore, lessThan(100));
    });

    test('a single stray sound is not a word', () {
      final a = analyse(
        read(
          p,
          before: {
            3: (s) => s
              ..phone('h', 2)
              ..blank(3),
          },
        ),
      );
      expect(a.extras, isEmpty);
    });
  });

  group('intrusive r (British English is non-rhotic)', () {
    final farm = buildPassage(
      id: 'farm',
      level: 1,
      title: 'Farm',
      text: 'a farm far away very far',
      ipa: ['ə', 'f ˈɑː m', 'f ˈɑː', 'ə w ˈeɪ', 'v ˈɛ ɹ i', 'f ˈɑː'],
    );

    test('an r after a vowel is reported and capped', () {
      final a = analyse(
        read(
          farm,
          subs: {
            1: {1: 'ɑːɹ'},
          },
        ),
        farm,
      );
      final ah = a.words[1].phonemes[1];
      expect(ah.heard, 'ɑːɹ');
      expect(
        const TableTips().tipFor('ɑː', ah.heard),
        "In British English, don't sound the r here.",
      );
    });

    test('a separate r sound after a vowel is caught', () {
      final s = Synth();
      s.blank(edge);
      s.say(farm.words[0], frames: 5, gap: 3);
      s
        ..phone('f', 5)
        ..phone('ɑː', 5)
        ..phone('ɹ', 3)
        ..phone('m', 5)
        ..blank(3);
      for (final w in farm.words.skip(2)) {
        s.say(w, frames: 5, gap: 3);
      }
      s.blank(edge);
      final a = scorer.analyse(farm, s.build(), const []);
      final ah = a.words[1].phonemes[1];
      expect(ah.heard, 'ɑːɹ');
      expect(ah.score, lessThanOrEqualTo(scorer.config.intrusiveRScore));
    });

    test(
      'linking r before a vowel and a written r are fine; final r is not',
      () {
        final s = Synth();
        s.blank(edge);
        s.say(farm.words[0], frames: 5, gap: 3);
        s.say(farm.words[1], frames: 5, gap: 3);
        s
          ..phone('f', 5)
          ..phone('ɑː', 5)
          ..phone('ɹ', 3) // linking r: "far_away"
          ..blank(3);
        s.say(farm.words[3], frames: 5, gap: 3);
        s.say(farm.words[4], frames: 5, gap: 3); // "very" has a written r
        s
          ..phone('f', 5)
          ..phone('ɑː', 5)
          ..phone('ɹ', 3) // final r
          ..blank(edge);
        final a = scorer.analyse(farm, s.build(), const []);
        expect(a.words[2].phonemes[1].heard, isNull);
        expect(a.words[4].phonemes[1].heard, isNull);
        expect(a.words[5].phonemes[1].heard, 'ɑːɹ');
      },
    );
  });

  group('word scores', () {
    test('stressed vowels weigh 1.5', () {
      // Cap off (I2-eval's tuned cap of worst + 40 would bind here and hide the
      // weighting).
      const uncapped = GopPronunciationScorer(
        config: ScoringConfig(wordMaxAboveWorst: 100),
      );
      final r = read(
        p,
        subs: {
          14: {1: 'æ'},
        },
      );
      final farm = uncapped.analyse(p, r.post, r.speech).words[14];
      final s = [for (final ph in farm.phonemes) ph.score];
      expect(farm.score, ((s[0] + 1.5 * s[1] + s[2]) / 3.5).round());
    });

    test('thresholds come from the config', () {
      const strict = GopPronunciationScorer(
        config: ScoringConfig(goodThreshold: 101, closeThreshold: 101),
      );
      final r = read(p);
      final res = strict.score(p, r.post, r.speech);
      expect(res.words.every((w) => w.status == WordStatus.fix), isTrue);
    });

    test('unscorable words are skipped by the alignment', () {
      final q = p.copyWith(
        words: [
          for (final w in p.words)
            w.index == 1 ? w.copyWith(scorable: false, phonemes: []) : w,
        ],
      );
      final a = analyse(read(q), q);
      expect(a.words[1].status, WordStatus.notScored);
      expect(a.words.where((w) => w.status == WordStatus.good), hasLength(26));
    });

    test('a passage with nothing scorable has accuracy 0', () {
      final q = p.copyWith(
        words: [
          for (final w in p.words) w.copyWith(scorable: false, phonemes: []),
        ],
      );
      final s = Synth()..blank(50);
      final a = scorer.analyse(q, s.build(), const []);
      expect(a.accuracy, 0);
      expect(a.alignment, isNull);
      expect(a.extras, isEmpty);
    });
  });

  group('phonemes the vocab lacks', () {
    final odd = buildPassage(
      id: 'odd',
      level: 1,
      title: 'Odd',
      text: 'cat tok',
      ipa: ['k ʘ t', 'ʘ'],
    );

    test(
      'take the word mean and a zero-length span; all-unknown is missed',
      () {
        final s = Synth()..blank(edge);
        s.say(odd.words[0], subs: {1: '', 0: 'k', 2: 't'}, frames: 5, gap: 3);
        s.blank(edge);
        final a = scorer.analyse(odd, s.build(), const []);
        final cat = a.words[0];
        expect(cat.phonemes, hasLength(3));
        expect(cat.phonemes[1].start, cat.phonemes[1].end);
        expect(cat.phonemes[1].score, cat.phonemes[0].score);
        expect(cat.status, WordStatus.good);
        expect(a.words[1].status, WordStatus.missed);
      },
    );
  });

  group('scoreWord', () {
    final word = p.words[1];

    test('a perfect single word is good with no fluency side effects', () {
      final s = Synth()..blank(edge);
      s.say(word, gap: 0);
      s.blank(edge);
      final r = scorer.scoreWord(word, s.build());
      expect(r.index, 1);
      expect(r.text, 'Thursday');
      expect(r.status, WordStatus.good);
    });

    test('silence is missed', () {
      final r = scorer.scoreWord(word, (Synth()..blank(40)).build());
      expect(r.status, WordStatus.missed);
      expect(r.index, 1);
    });
  });

  test('ids default from the time and tier is copied', () {
    final r = read(p);
    final light = Synth()..blank(edge);
    for (final w in p.words) {
      light.say(w);
    }
    final res = scorer.score(p, light.build(tier: ModelTier.light), r.speech);
    expect(res.id, startsWith('attempt-'));
    expect(res.tier, ModelTier.light);
  });

  test('works on the sample vocab (canned fixture posteriors)', () {
    final res = scorer.score(
      riverPassage,
      riverPosteriors,
      syntheticSpeech(riverPosteriors),
    );
    expect(res.redWords.map((w) => w.text), ['Thursday', 'castle', 'bath']);
    expect(res.words[11].phonemes[1].heard, 'æ');
  });
}
