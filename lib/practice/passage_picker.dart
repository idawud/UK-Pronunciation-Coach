/// Next-passage choice. Pure Dart; randomness comes from an injected [Random].
library;

import 'dart:math';

import '../core/models/passage.dart';
import 'level_rules.dart';

/// Which part of the mix a passage was chosen for.
enum PassageBucket {
  /// The current level, weighted to the weakest sounds (70%).
  current,

  /// A passage containing previously missed words (20%).
  review,

  /// A preview of the next level (10%).
  preview,

  /// Chosen for a requested sound tag (Practise tab).
  soundTag,
}

/// A chosen passage and why it was chosen.
typedef PassagePick = ({Passage passage, PassageBucket bucket});

/// Chooses passages with the 70 / 20 / 10 mix from docs/SPEC.md.
class PassagePicker {
  /// Creates a picker drawing from [random] (seed it in tests).
  PassagePicker(this.random);

  /// Source of randomness.
  final Random random;

  /// Share of picks from the current level.
  static const double currentShare = 0.7;

  /// Share of picks reviewing missed words.
  static const double reviewShare = 0.2;

  /// Share of picks previewing the next level (the rest).
  static const double previewShare = 1 - currentShare - reviewShare;

  /// Sessions within which a passage is not repeated (when possible).
  static const int noRepeatWithin = 10;

  /// Extra weight for a passage tagged with the weakest, 2nd and 3rd weakest sound.
  static const List<int> weakSoundBonus = [3, 2, 1];

  /// Picks the next passage from [library] (non-empty) for a user at [level].
  ///
  /// - [weakSounds]: the weakest sounds' IPA, weakest first (only 3 are used).
  /// - [reviewWords]: lower-cased words in the review queue (due ones are best).
  /// - [recentIds]: passage ids of recent sessions, newest first; the latest
  ///   [noRepeatWithin] are avoided where possible.
  /// - [soundTag]: when given, a passage tagged with it at or below `level + 1`
  ///   (any level when none is; the normal mix when no passage has the tag).
  ///
  /// When the rolled bucket has nothing fresh, falls back to the current level, then
  /// to levels within one of it, then to the least recently read passage at the
  /// nearest level.
  PassagePick pick({
    required List<Passage> library,
    required int level,
    List<String> weakSounds = const [],
    Set<String> reviewWords = const {},
    List<String> recentIds = const [],
    String? soundTag,
  }) {
    if (library.isEmpty) throw StateError('No passages available');
    final recent = recentIds.take(noRepeatWithin).toList();
    final recentSet = recent.toSet();
    bool fresh(Passage p) => !recentSet.contains(p.id);

    if (soundTag != null) {
      final tagged = library.where((p) => p.soundTags.contains(soundTag));
      final near = tagged.where((p) => p.level <= level + 1).toList();
      final pool = near.isNotEmpty ? near : tagged.toList();
      if (pool.isNotEmpty) {
        final freshPool = pool.where(fresh).toList();
        final passage = freshPool.isNotEmpty
            ? _closestRandom(freshPool, level)
            : _leastRecent(pool, level, recent);
        return (passage: passage, bucket: PassageBucket.soundTag);
      }
    }

    final weak = weakSounds.take(weakSoundBonus.length).toList();
    int weakWeight(Passage p) {
      var w = 1;
      for (var i = 0; i < weak.length; i++) {
        if (p.soundTags.contains(weak[i])) w += weakSoundBonus[i];
      }
      return w;
    }

    int reviewHits(Passage p) {
      if (reviewWords.isEmpty) return 0;
      final words = {for (final w in p.words) w.text.toLowerCase()};
      return words.where(reviewWords.contains).length;
    }

    List<(Passage, int)> candidates(PassageBucket bucket) => switch (bucket) {
      PassageBucket.review => [
        for (final p in library)
          if (p.level <= level + 1 && fresh(p))
            if (reviewHits(p) case final hits when hits > 0) (p, hits),
      ],
      PassageBucket.preview => [
        if (level < maxLevel)
          for (final p in library)
            if (p.level == level + 1 && fresh(p)) (p, weakWeight(p)),
      ],
      _ => [
        for (final p in library)
          if (p.level == level && fresh(p)) (p, weakWeight(p)),
      ],
    };

    final rolled = _roll();
    for (final bucket in {rolled, PassageBucket.current}) {
      final c = candidates(bucket);
      if (c.isNotEmpty) return (passage: _weighted(c), bucket: bucket);
    }
    final nearby = [
      for (final p in library)
        if ((p.level - level).abs() <= 1 && fresh(p)) (p, weakWeight(p)),
    ];
    if (nearby.isNotEmpty) {
      return (passage: _weighted(nearby), bucket: PassageBucket.current);
    }
    return (
      passage: _leastRecent(library, level, recent),
      bucket: PassageBucket.current,
    );
  }

  PassageBucket _roll() {
    final r = random.nextDouble();
    if (r < currentShare) return PassageBucket.current;
    if (r < currentShare + reviewShare) return PassageBucket.review;
    return PassageBucket.preview;
  }

  Passage _weighted(List<(Passage, int)> items) {
    final total = items.fold<int>(0, (s, e) => s + e.$2);
    var r = random.nextInt(total);
    for (final (p, w) in items) {
      if (r < w) return p;
      r -= w;
    }
    return items.last.$1; // coverage:ignore-line (unreachable)
  }

  /// A random passage among those at the level closest to [level].
  Passage _closestRandom(List<Passage> pool, int level) {
    final best = pool
        .map((p) => (p.level - level).abs())
        .reduce((a, b) => a < b ? a : b);
    final closest = pool.where((p) => (p.level - level).abs() == best).toList();
    return closest[random.nextInt(closest.length)];
  }

  /// The passage at the level closest to [level] read longest ago in [recent]
  /// (newest first); unread passages count as oldest.
  static Passage _leastRecent(
    List<Passage> pool,
    int level,
    List<String> recent,
  ) {
    int age(Passage p) {
      final i = recent.indexOf(p.id);
      return i < 0 ? recent.length : i;
    }

    final sorted = [...pool]
      ..sort((a, b) {
        final d = (a.level - level).abs().compareTo((b.level - level).abs());
        if (d != 0) return d;
        final r = age(b).compareTo(age(a));
        return r != 0 ? r : a.id.compareTo(b.id);
      });
    return sorted.first;
  }
}
