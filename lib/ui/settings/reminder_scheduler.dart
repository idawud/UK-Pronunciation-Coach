import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'local_notifications_reminder_scheduler.dart';

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

/// For platforms without local notifications (desktop, `flutter test` hosts): the
/// reminder time is still saved in the profile, but no notification is shown.
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

/// The reminder scheduler: local notifications on Android and iOS, else
/// [UnavailableReminderScheduler]. Override in tests.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => platformReminderScheduler(),
);

/// Re-schedules the saved daily reminder once at start-up, so it survives an OS
/// restore, an app update or a time-zone change. Never asks for permission and never
/// throws: a failure only means no reminder until the user changes the setting.
final reminderRestoreProvider = FutureProvider<void>((ref) async {
  final scheduler = ref.read(reminderSchedulerProvider);
  if (!scheduler.isSupported) return;
  // The app (and with it the database) can shut down while this is in flight; the
  // read then fails because the channel closed, which is not a scheduling failure.
  var disposed = false;
  ref.onDispose(() => disposed = true);
  try {
    final repository = ref.read(progressRepositoryProvider);
    final minutes = (await repository.profile()).reminderMinutes;
    if (disposed) return;
    if (minutes != null) await scheduler.scheduleDaily(minutes);
  } on Object catch (e) {
    if (disposed) return;
    debugPrint('Reminder: could not restore the daily reminder ($e).');
  }
});
