import 'package:flutter/material.dart';

/// Grid of the last [weeks] weeks (Monday first), ending with the week of [today].
/// Practised days are filled with the primary colour and carry a tick, so the state
/// does not rely on colour alone; today is outlined.
class StreakCalendar extends StatelessWidget {
  /// Creates the calendar.
  const StreakCalendar({
    super.key,
    required this.today,
    required this.practisedDays,
    this.weeks = 5,
  });

  /// Today's local date (midnight).
  final DateTime today;

  /// Local dates (midnight) with practice.
  final List<DateTime> practisedDays;

  /// Number of weeks shown.
  final int weeks;

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = {
      for (final d in practisedDays) DateTime(d.year, d.month, d.day),
    };
    final monday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - DateTime.monday),
    );
    final start = DateTime(
      monday.year,
      monday.month,
      monday.day - 7 * (weeks - 1),
    );
    final count = days
        .where((d) => !d.isBefore(start) && !d.isAfter(today))
        .length;

    return Semantics(
      label: 'Practised on $count of the last ${weeks * 7} days',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Row(
              children: [
                for (final l in _dayLetters)
                  Expanded(
                    child: Center(
                      child: Text(l, style: theme.textTheme.labelSmall),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var w = 0; w < weeks; w++)
              Row(
                children: [
                  for (var d = 0; d < 7; d++)
                    Expanded(
                      child: _DayCell(
                        date: DateTime(
                          start.year,
                          start.month,
                          start.day + w * 7 + d,
                        ),
                        today: today,
                        practised: days.contains(
                          DateTime(
                            start.year,
                            start.month,
                            start.day + w * 7 + d,
                          ),
                        ),
                        scheme: scheme,
                        textTheme: theme.textTheme,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.today,
    required this.practised,
    required this.scheme,
    required this.textTheme,
  });

  final DateTime date;
  final DateTime today;
  final bool practised;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final isToday = date == today;
    final future = date.isAfter(today);
    return Padding(
      padding: const EdgeInsets.all(3),
      child: AspectRatio(
        aspectRatio: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 44),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: practised
                  ? scheme.primary
                  : future
                  ? null
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: isToday
                  ? Border.all(color: scheme.onSurface, width: 2)
                  : null,
            ),
            child: Center(
              child: practised
                  ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                  : Text(
                      '${date.day}',
                      style: textTheme.labelSmall?.copyWith(
                        color: future
                            ? scheme.outline
                            : scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
