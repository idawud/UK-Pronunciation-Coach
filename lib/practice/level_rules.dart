/// Level and placement rules. Pure Dart.
library;

import '../core/models/level_change.dart';

/// Lowest level.
const int minLevel = 1;

/// Highest level.
const int maxLevel = 6;

/// Passages in a row needed to change level.
const int runLength = 3;

/// Overall score at or above which a passage counts towards moving up.
const int moveUpAt = 85;

/// Overall score below which a passage counts towards moving down.
const int moveDownBelow = 60;

/// Applies the level rules to [run]: the overall scores of the passages read since the
/// last level change, newest first. Moves up after [runLength] in a row at [moveUpAt]+
/// and down after [runLength] in a row under [moveDownBelow], staying within
/// [minLevel]-[maxLevel]. Returns the change (timestamped [at]) or null.
LevelChange? levelChangeFor(int level, List<int> run, DateTime at) {
  if (run.length < runLength) return null;
  final last = run.take(runLength);
  if (last.every((s) => s >= moveUpAt) && level < maxLevel) {
    final to = level + 1;
    return LevelChange(
      from: level,
      to: to,
      reason:
          'Three passages in a row at $moveUpAt or more: welcome to level $to.',
      at: at,
    );
  }
  if (last.every((s) => s < moveDownBelow) && level > minLevel) {
    final to = level - 1;
    return LevelChange(
      from: level,
      to: to,
      reason:
          'Three passages in a row under $moveDownBelow: back to level $to '
          'to build confidence.',
      at: at,
    );
  }
  return null;
}

/// Overall score at which a placement passage counts as read well enough.
const int placementPass = 60;

/// Overall score at which a placement passage counts as read strongly.
const int placementStrong = 80;

/// Start level from the placement scores for the level 1, 3 and 5 passages, in that
/// order (missing scores count as 0).
///
/// A gated ladder: passing level 1 gives 2; passing level 3 gives 3 (4 when strong);
/// passing level 5 as well gives 5 (6 when strong). A higher passage only counts when
/// the one below it was passed, so a single lucky reading cannot skip levels, and a
/// higher score never gives a lower level.
int placementLevelFor(List<int> scores) {
  int s(int i) => i < scores.length ? scores[i] : 0;
  var level = minLevel;
  if (s(0) < placementPass) return level;
  level = 2;
  if (s(1) < placementPass) return level;
  level = s(1) >= placementStrong ? 4 : 3;
  if (s(2) < placementPass) return level;
  return s(2) >= placementStrong ? 6 : 5;
}
