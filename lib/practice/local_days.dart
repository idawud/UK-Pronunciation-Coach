/// Local calendar days for streaks and daily minutes. Pure Dart.
library;

import '../core/models/practice_session.dart';

/// Converts an instant to wall-clock time in the user's time zone. The returned
/// DateTime's year / month / day / hour fields are the local wall clock.
///
/// The default, [deviceWallClock], uses the device time zone. Tests inject a fixed
/// zone (e.g. Europe/London rules) to cover clock changes and travel.
typedef WallClock = DateTime Function(DateTime instant);

/// The device time zone: UTC instants are converted with `toLocal()`; local DateTimes
/// already hold device wall-clock time.
DateTime deviceWallClock(DateTime instant) =>
    instant.isUtc ? instant.toLocal() : instant;

/// A local calendar day, independent of time zone and daylight saving.
extension type const LocalDay._(int dayNumber) implements Object {
  /// The local day of [instant] under [wallClock].
  factory LocalDay.of(DateTime instant, WallClock wallClock) {
    final w = wallClock(instant);
    return LocalDay.ymd(w.year, w.month, w.day);
  }

  /// The day with the given calendar date (normalised, so day 0 is the previous
  /// month's last day).
  factory LocalDay.ymd(int year, int month, int day) => LocalDay._(
    DateTime.utc(year, month, day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay,
  );

  /// The day [days] later (earlier when negative).
  LocalDay plus(int days) => LocalDay._(dayNumber + days);

  /// This day as local midnight (`DateTime(y, m, d)`), as used in
  /// `DailyProgress.practisedDays`.
  DateTime toDate() {
    final u = DateTime.fromMillisecondsSinceEpoch(
      dayNumber * Duration.millisecondsPerDay,
      isUtc: true,
    );
    return DateTime(u.year, u.month, u.day);
  }
}

/// Splits [session] across the local days it covers, by elapsed time. A session that
/// runs past local midnight credits each day with the part that fell on it.
/// Non-positive durations credit nothing.
Map<LocalDay, Duration> splitByLocalDay(
  PracticeSession session,
  WallClock wallClock,
) {
  final out = <LocalDay, Duration>{};
  if (session.duration <= Duration.zero) return out;
  var start = session.start;
  final end = session.start.add(session.duration);
  while (start.isBefore(end)) {
    final day = LocalDay.of(start, wallClock);
    if (LocalDay.of(end, wallClock) == day) {
      out[day] = (out[day] ?? Duration.zero) + end.difference(start);
      break;
    }
    // Binary search for the first microsecond on a later local day.
    var lo = start; // on `day`
    var hi = end; // on a later day
    while (hi.difference(lo) > const Duration(microseconds: 1)) {
      final mid = lo.add(
        Duration(microseconds: hi.difference(lo).inMicroseconds ~/ 2),
      );
      if (LocalDay.of(mid, wallClock) == day) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    out[day] = (out[day] ?? Duration.zero) + hi.difference(start);
    start = hi;
  }
  return out;
}

/// Consecutive practised days ending today, or ending yesterday when today has no
/// practice yet. Zero once a whole local day has passed without practice.
int streakFor(Set<LocalDay> practised, LocalDay today) {
  var cursor = practised.contains(today) ? today : today.plus(-1);
  var streak = 0;
  while (practised.contains(cursor)) {
    streak++;
    cursor = cursor.plus(-1);
  }
  return streak;
}
