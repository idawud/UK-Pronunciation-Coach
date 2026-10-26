import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_scheduler.dart';

/// The plug-in calls [LocalNotificationsReminderScheduler] needs, behind a seam so
/// tests can check the scheduling logic without a device.
abstract interface class ReminderNotifications {
  /// Sets up the plug-in. Called once, before anything else.
  Future<void> initialize();

  /// The device's IANA time zone, e.g. `Europe/London`.
  Future<String> localTimeZone();

  /// Asks to show notifications. True when allowed.
  Future<bool> requestPermission();

  /// Shows a notification every day at the wall-clock time of [first], starting
  /// at [first], replacing any notification with the same [id].
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime first,
  });

  /// Cancels the notification with [id].
  Future<void> cancel(int id);
}

/// [ReminderNotifications] on `flutter_local_notifications` and `flutter_timezone`.
/// Everything stays on the device: no push service, no network.
class PluginReminderNotifications implements ReminderNotifications {
  /// Creates the adapter; [plugin] is injectable for tests.
  PluginReminderNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Android notification channel for the reminder.
  static const channelId = 'daily_reminder';

  /// Channel name shown in Android's notification settings.
  static const channelName = 'Daily reminder';

  @override
  Future<void> initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        // White silhouette (R1-release): Android draws small icons as an alpha mask.
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        // Ask only when the user switches the reminder on, not at start-up.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }

  @override
  Future<String> localTimeZone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      // Android 13+: the POST_NOTIFICATIONS prompt; older: whether notifications
      // are switched on for the app.
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime first,
  }) => _plugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    scheduledDate: first,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'A daily nudge to practise reading aloud.',
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    ),
    // Inexact: a practice nudge does not need SCHEDULE_EXACT_ALARM.
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}

/// [ReminderScheduler] on local notifications: one notification a day at the chosen
/// time in the device's time zone (so it follows BST / GMT changes). The plug-in is
/// set up lazily on first use; Android reschedules after a reboot through the
/// plug-in's boot receiver, and the app calls [scheduleDaily] again on start-up
/// (see `reminderRestoreProvider`) so a time-zone change is picked up.
class LocalNotificationsReminderScheduler implements ReminderScheduler {
  /// Creates the scheduler. [notifications] and [now] are injectable for tests.
  LocalNotificationsReminderScheduler({
    ReminderNotifications? notifications,
    DateTime Function()? now,
  }) : _notifications = notifications ?? PluginReminderNotifications(),
       _now = now ?? DateTime.now;

  final ReminderNotifications _notifications;
  final DateTime Function() _now;
  Future<tz.Location>? _ready;

  /// Notification id of the daily reminder.
  static const notificationId = 1;

  /// Notification title.
  static const title = 'Time to practise';

  /// Notification text.
  static const body = 'A few minutes of reading keeps your streak going.';

  @override
  bool get isSupported => true;

  Future<tz.Location> _init() => _ready ??= () async {
    try {
      await _notifications.initialize();
      tzdata.initializeTimeZones();
      return await _location();
    } catch (_) {
      _ready = null; // try again next time
      rethrow;
    }
  }();

  /// The device's zone, or a fixed-offset zone when the name is unknown.
  Future<tz.Location> _location() async {
    try {
      return tz.getLocation(await _notifications.localTimeZone());
    } on Object catch (e) {
      debugPrint('Reminder: unknown time zone ($e); using a fixed offset.');
      final offset = _now().timeZoneOffset;
      return tz.Location('Local', [tz.minTime], [0], [
        tz.TimeZone(offset, isDst: false, abbreviation: 'LOCAL'),
      ]);
    }
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    return _notifications.requestPermission();
  }

  @override
  Future<void> scheduleDaily(int minutesAfterMidnight) async {
    final location = await _init();
    final now = tz.TZDateTime.from(_now(), location);
    await _notifications.scheduleDaily(
      id: notificationId,
      title: title,
      body: body,
      first: nextReminder(minutesAfterMidnight, now),
    );
  }

  @override
  Future<void> cancel() async {
    await _init();
    await _notifications.cancel(notificationId);
  }

  /// The first time at or after [now] (exclusive) whose wall-clock time in
  /// [now]'s zone is [minutesAfterMidnight]. Built from calendar fields, not by
  /// adding 24 hours, so it stays on the same wall-clock time across BST / GMT.
  static tz.TZDateTime nextReminder(
    int minutesAfterMidnight,
    tz.TZDateTime now,
  ) {
    RangeError.checkValueInInterval(
      minutesAfterMidnight,
      0,
      24 * 60 - 1,
      'minutesAfterMidnight',
    );
    final h = minutesAfterMidnight ~/ 60, m = minutesAfterMidnight % 60;
    final today = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day,
      h,
      m,
    );
    if (today.isAfter(now)) return today;
    return tz.TZDateTime(now.location, now.year, now.month, now.day + 1, h, m);
  }
}

/// Local notifications on Android and iOS; [UnavailableReminderScheduler] on other
/// platforms (desktop, and the host running `flutter test`). Uses the real OS, not
/// `defaultTargetPlatform`, which widget tests set to Android.
ReminderScheduler platformReminderScheduler({bool? mobile}) {
  final isMobile = mobile ?? (Platform.isAndroid || Platform.isIOS);
  return isMobile
      ? LocalNotificationsReminderScheduler()
      : const UnavailableReminderScheduler();
}
