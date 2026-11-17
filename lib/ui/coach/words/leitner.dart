import 'lost_word.dart';

/// Leitner interval in days for each box, indexed by `box - 1`. Box 1 is due the same
/// day. Only boxes 1 to 5 are reachable (see [leitnerMaxBox]), so the final 16-day
/// entry is kept for the agreed table but never used.
const List<int> leitnerIntervalDays = [0, 1, 2, 4, 8, 16];

/// Lowest Leitner box.
const int leitnerMinBox = 1;

/// Highest Leitner box. Recalls past this keep the word in the top box.
const int leitnerMaxBox = 5;

/// Days until the next review for [box] (clamped to the valid boxes).
int leitnerIntervalFor(int box) =>
    leitnerIntervalDays[box.clamp(leitnerMinBox, leitnerMaxBox) - 1];

/// Applies one review answer to [w] at time [now].
///
/// Recalled: the box goes up by one (capped at [leitnerMaxBox]) and the word is due
/// after the interval of the new box. Missed: the word drops to box 1, gains a lapse
/// and is due at [now].
///
/// Pure: no I/O and no clock reads, so tests can pin [now].
LostWord review(LostWord w, bool recalled, DateTime now) {
  if (recalled) {
    final box = (w.box.clamp(leitnerMinBox, leitnerMaxBox) + 1).clamp(
      leitnerMinBox,
      leitnerMaxBox,
    );
    return w.copyWith(
      box: box,
      due: now.add(Duration(days: leitnerIntervalFor(box))),
    );
  }
  return w.copyWith(box: leitnerMinBox, lapses: w.lapses + 1, due: now);
}

/// True when [w] is due at [now]: its due time is not after [now].
bool isDue(LostWord w, DateTime now) => !w.due.isAfter(now);
