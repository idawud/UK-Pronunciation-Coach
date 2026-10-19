import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin adapter over local notifications for the daily practice reminder. Everything is
/// scheduled on the device; nothing goes to a server.
abstract interface class ReminderScheduler {
  /// Whether this build can show reminders at all.
  bool get isSupported;

  /// Asks for permission to show notifications (Android 13+, iOS). True when allowed.
  Future<bool> requestPermission();

  /// Schedules (or reschedules) one daily reminder at [minutesAfterMidnight] local
  /// time, replacing any earlier one.
  Future<void> scheduleDaily(int minutesAfterMidnight);

  /// Cancels the daily reminder. Safe to call when none is scheduled.
  Future<void> cancel();
}

/// Used until the notification plug-in is approved (see
/// docs/contract-requests/U4-progress.md): the reminder time is still saved in the
/// profile, but no notification is shown.
class UnavailableReminderScheduler implements ReminderScheduler {
  /// Creates the scheduler.
  const UnavailableReminderScheduler();

  @override
  bool get isSupported => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleDaily(int minutesAfterMidnight) async {}

  @override
  Future<void> cancel() async {}
}

/// The reminder scheduler. Override in tests; I1 binds the real one.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => const UnavailableReminderScheduler(),
);
