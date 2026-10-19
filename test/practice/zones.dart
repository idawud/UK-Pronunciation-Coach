import 'package:uk_pronunciation_coach/practice/local_days.dart';

/// Last Sunday of [month] in [year], at 01:00 UTC (when UK clocks change).
DateTime _lastSunday1amUtc(int year, int month) {
  var d = DateTime.utc(year, month + 1, 0, 1);
  while (d.weekday != DateTime.sunday) {
    d = DateTime.utc(d.year, d.month, d.day - 1, 1);
  }
  return d;
}

/// Europe/London rules: GMT, BST (UTC+1) from 01:00 UTC on the last Sunday of March
/// to 01:00 UTC on the last Sunday of October. Takes UTC instants (or converts local
/// DateTimes with `toUtc`); the result's fields are London wall-clock time.
DateTime europeLondon(DateTime instant) {
  final t = instant.toUtc();
  final bst =
      !t.isBefore(_lastSunday1amUtc(t.year, 3)) &&
      t.isBefore(_lastSunday1amUtc(t.year, 10));
  return bst ? t.add(const Duration(hours: 1)) : t;
}

/// A fixed-offset zone (no daylight saving), e.g. UTC-5 for New York in winter.
WallClock fixedOffset(Duration offset) =>
    (instant) => instant.toUtc().add(offset);
