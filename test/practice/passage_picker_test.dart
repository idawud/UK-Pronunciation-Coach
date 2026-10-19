import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/practice/passage_picker.dart';

/// 6 levels x 20 passages. Passage `l<level>-<n>` is tagged θ when n < 5 and ʌ when
/// 5 <= n < 10; level-2 passages with n < 4 contain the word "castle".
List<Passage> library() => [
  for (var level = 1; level <= 6; level++)
    for (var n = 0; n < 20; n++)
      buildPassage(
        id: 'l$level-${n.toString().padLeft(2, '0')}',
        level: level,
        title: 'Passage $level-$n',
        text: level == 2 && n < 4 ? 'The old castle.' : 'The old house.',
        ipa: [
          'ð ə',
          'ˈəʊ l d',
          if (level == 2 && n < 4) 'k ˈɑː s ə l' else 'h ˈaʊ s',
        ],
        soundTags: [if (n < 5) 'θ', if (n >= 5 && n < 10) 'ʌ'],
      ),
];

void main() {
  final lib = library();

  test('empty library throws', () {
    expect(
      () => PassagePicker(Random(1)).pick(library: const [], level: 1),
      throwsStateError,
    );
  });

  test('70 / 20 / 10 mix with a fixed seed', () {
    final picker = PassagePicker(Random(42));
    const n = 5000;
    final byBucket = <PassageBucket, int>{};
    final byLevel = <int, int>{};
    for (var i = 0; i < n; i++) {
      final pick = picker.pick(library: lib, level: 3, reviewWords: {'castle'});
      byBucket.update(pick.bucket, (c) => c + 1, ifAbsent: () => 1);
      byLevel.update(pick.passage.level, (c) => c + 1, ifAbsent: () => 1);
    }
    double share(int? c) => (c ?? 0) / n;
    expect(share(byBucket[PassageBucket.current]), closeTo(0.7, 0.03));
    expect(share(byBucket[PassageBucket.review]), closeTo(0.2, 0.03));
    expect(share(byBucket[PassageBucket.preview]), closeTo(0.1, 0.02));
    // Review words only live in level-2 passages here.
    expect(share(byLevel[3]), closeTo(0.7, 0.03));
    expect(share(byLevel[2]), closeTo(0.2, 0.03));
    expect(share(byLevel[4]), closeTo(0.1, 0.02));
    expect(byLevel.keys.toSet(), {2, 3, 4});
  });

  test('current level is weighted to the weakest sounds', () {
    final picker = PassagePicker(Random(7));
    var theta = 0, strut = 0, other = 0, current = 0;
    for (var i = 0; i < 6000; i++) {
      final pick = picker.pick(
        library: lib,
        level: 3,
        weakSounds: ['θ', 'ʌ', 'x', 'y'],
      );
      if (pick.bucket != PassageBucket.current) continue;
      current++;
      final tags = pick.passage.soundTags;
      if (tags.contains('θ')) {
        theta++;
      } else if (tags.contains('ʌ')) {
        strut++;
      } else {
        other++;
      }
    }
    // Weights: θ 1+3 = 4, ʌ 1+2 = 3, untagged 1; 5 + 5 + 10 passages.
    const total = 5 * 4 + 5 * 3 + 10 * 1;
    expect(theta / current, closeTo(20 / total, 0.03));
    expect(strut / current, closeTo(15 / total, 0.03));
    expect(other / current, closeTo(10 / total, 0.03));
  });

  test('no review words: the review share falls back to the current level', () {
    final picker = PassagePicker(Random(3));
    var level3 = 0;
    for (var i = 0; i < 2000; i++) {
      if (picker.pick(library: lib, level: 3).passage.level == 3) level3++;
    }
    expect(level3 / 2000, closeTo(0.9, 0.03));
  });

  test('level 6 has no preview: always level 6', () {
    final picker = PassagePicker(Random(5));
    for (var i = 0; i < 300; i++) {
      expect(picker.pick(library: lib, level: 6).passage.level, 6);
    }
  });

  test('never repeats one of the last 10 sessions when avoidable', () {
    final picker = PassagePicker(Random(11));
    final recent = <String>[];
    for (var i = 0; i < 500; i++) {
      final p = picker.pick(library: lib, level: 3, recentIds: recent).passage;
      expect(recent.take(10), isNot(contains(p.id)));
      recent.insert(0, p.id);
    }
  });

  test('falls back to nearby levels, then the least recently read', () {
    final small = [
      for (final p in lib)
        if (p.id == 'l3-00' ||
            p.id == 'l3-01' ||
            p.id == 'l4-00' ||
            p.id == 'l6-00')
          p,
    ];
    final picker = PassagePicker(Random(1));
    // Level 3 all recent: nearby level 4 is used.
    expect(
      picker
          .pick(library: small, level: 3, recentIds: ['l3-00', 'l3-01'])
          .passage
          .id,
      'l4-00',
    );
    // Everything nearby recent: the level-3 passage read longest ago.
    expect(
      picker
          .pick(
            library: small,
            level: 3,
            recentIds: ['l3-00', 'l4-00', 'l3-01'],
          )
          .passage
          .id,
      'l3-01',
    );
    // A passage read more than 10 sessions ago is fresh again.
    final old = ['l3-01', for (var i = 0; i < 10; i++) 'x$i', 'l3-00'];
    expect(
      picker
          .pick(library: small.sublist(0, 1), level: 3, recentIds: old)
          .passage
          .id,
      'l3-00',
    );
  });

  group('soundTag', () {
    test('tagged at or below level + 1, closest to the level, fresh first', () {
      final picker = PassagePicker(Random(9));
      for (var i = 0; i < 200; i++) {
        final pick = picker.pick(library: lib, level: 3, soundTag: 'θ');
        expect(pick.bucket, PassageBucket.soundTag);
        expect(pick.passage.soundTags, contains('θ'));
        expect(pick.passage.level, 3);
      }
      final recent = [for (var n = 0; n < 5; n++) 'l3-0$n'];
      final p = picker.pick(
        library: lib,
        level: 3,
        soundTag: 'θ',
        recentIds: recent,
      );
      expect(p.passage.level, isNot(3));
      expect(p.passage.level, anyOf(2, 4));
    });

    test('falls back to any level when none is at or below level + 1', () {
      final high = [
        for (final p in lib)
          if (p.level == 6) p,
      ];
      final pick = PassagePicker(Random(2))
          .pick(library: high, level: 1, soundTag: 'ʌ');
      expect(pick.passage.level, 6);
      expect(pick.passage.soundTags, contains('ʌ'));
    });

    test('all tagged passages recent: least recently read', () {
      final tagged = [
        for (final p in lib)
          if (p.level == 1 && p.soundTags.contains('θ')) p,
      ];
      final recent = [
        for (final p in tagged) p.id,
      ]; // l1-00 newest ... l1-04 oldest
      final pick = PassagePicker(Random(2))
          .pick(library: tagged, level: 1, soundTag: 'θ', recentIds: recent);
      expect(pick.passage.id, 'l1-04');
    });

    test('unknown tag: the normal mix', () {
      final pick = PassagePicker(Random(2))
          .pick(library: lib, level: 2, soundTag: 'nope');
      expect(pick.bucket, isNot(PassageBucket.soundTag));
    });
  });
}
