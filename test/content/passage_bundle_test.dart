// Content checks on the committed bundle (assets/content/), built by
// tools/content/build.py. CI also rebuilds it and fails on any difference.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/scoring/data/phoneme_map.dart';

final _word = RegExp(r"[A-Za-z]+(?:['’][A-Za-z]+)*");

/// Level -> [min, max] word count (docs/SPEC.md level table).
const _lengths = {
  1: [8, 12],
  2: [25, 35],
  3: [50, 70],
  4: [85, 115],
  5: [135, 165],
  6: [180, 220],
};

void main() {
  final bundle = jsonDecode(
    File('assets/content/passages.v1.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  List<Passage> read(String key) => [
    for (final p in bundle[key] as List<dynamic>)
      Passage.fromJson(p as Map<String, dynamic>),
  ];
  final library = read('passages');
  final placement = read('placement');
  final everything = [...library, ...placement];

  test('bundle version 1', () => expect(bundle['version'], 1));

  test('20 passages at each level 1-6, ids l<level>-NNN', () {
    for (var level = 1; level <= 6; level++) {
      final at = library.where((p) => p.level == level).toList();
      expect(at, hasLength(20), reason: 'level $level');
      for (final p in at) {
        expect(p.id, matches(RegExp('^l$level-\\d{3}\$')));
      }
    }
  });

  test('placement set is one passage each from levels 1, 3 and 5', () {
    expect(placement.map((p) => p.level), [1, 3, 5]);
    expect(placement.map((p) => p.id), [
      'placement-l1',
      'placement-l3',
      'placement-l5',
    ]);
  });

  test('ids are unique across library and placement', () {
    expect(everything.map((p) => p.id).toSet(), hasLength(everything.length));
  });

  for (final p in everything) {
    test('${p.id} is well formed', () {
      expect(p.title, isNotEmpty);
      expect(p.soundTags, isNotEmpty);
      final [lo, hi] = _lengths[p.level]!;
      expect(p.words.length, inInclusiveRange(lo, hi));
      final tokens = _word.allMatches(p.text).toList();
      expect(p.words, hasLength(tokens.length));
      for (var i = 0; i < p.words.length; i++) {
        final w = p.words[i];
        expect(w.index, i);
        expect(w.offset, tokens[i].start);
        expect(w.text, tokens[i].group(0));
        expect(w.scorable, isTrue, reason: '${w.text} has phonemes');
        expect(w.phonemes, isNotEmpty, reason: w.text);
        expect(
          w.phonemes.where((ph) => ph.stress == 1).length,
          lessThanOrEqualTo(1),
          reason: '${w.text}: one primary stress at most',
        );
        for (final ph in w.phonemes) {
          expect(
            ssbePhonemeMap.keys,
            contains(ph.ipa),
            reason:
                '${p.id} ${w.text}: /${ph.ipa}/ is not a phoneme the scorer maps',
          );
          if (ph.stress != 0) {
            expect(
              ssbeVowels,
              contains(ph.ipa),
              reason: 'only vowels carry stress',
            );
          }
        }
      }
      // Sentence splitting (Passage.sentenceRange) covers every word.
      expect(p.sentenceRange(p.words.length - 1).end, p.words.length);
      if (p.level == 1) {
        expect(p.sentenceRange(0), (start: 0, end: p.words.length));
      }
    });
  }

  test('minimal pairs: 40+, grouped by contrast, one sound apart', () {
    final json = jsonDecode(
      File('assets/content/minimal_pairs.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final pairs = [
      for (final p in json['pairs'] as List<dynamic>)
        MinimalPair.fromJson(p as Map<String, dynamic>),
    ];
    expect(pairs.length, greaterThanOrEqualTo(40));
    final seen = <String>[];
    for (final p in pairs) {
      if (seen.isEmpty || seen.last != p.contrast) {
        expect(seen, isNot(contains(p.contrast)), reason: 'grouped');
        seen.add(p.contrast);
      }
      final [a, b] = p.contrast.split('-');
      final diff = [
        for (var i = 0; i < p.phonemesA.length; i++)
          if (p.phonemesA[i].ipa != p.phonemesB[i].ipa)
            (p.phonemesA[i].ipa, p.phonemesB[i].ipa),
      ];
      expect(p.phonemesA.length, p.phonemesB.length);
      expect(diff, [(a, b)], reason: '${p.wordA}/${p.wordB}');
    }
    expect(seen.length, greaterThanOrEqualTo(10));
  });

  test('SOURCES.md lists every passage', () {
    final sources = File('assets/content/SOURCES.md').readAsStringSync();
    for (final p in everything) {
      expect(sources, contains('| ${p.id} |'));
    }
  });

  test('Britfone table ships with its MIT licence', () {
    final licence = File('assets/content/BRITFONE_LICENSE.txt')
        .readAsStringSync();
    expect(licence, contains('MIT License'));
    expect(licence, contains('Jose Llarena'));
  });
}
