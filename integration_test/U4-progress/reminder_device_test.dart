// On-device test for U4's daily reminder: the real flutter_local_notifications
// plug-in behind LocalNotificationsReminderScheduler. Local only, no network.
//
//   flutter test integration_test/U4-progress -d <device>
//
// Headless: it never calls requestPermission() (that shows a system dialog).
// Android lets an app schedule without POST_NOTIFICATIONS (the notification is
// just not shown), so scheduling and cancelling are checked through the plug-in's
// pending list. iOS refuses to schedule until the user has allowed notifications,
// so the test is skipped there.
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uk_pronunciation_coach/ui/settings/local_notifications_reminder_scheduler.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'schedules, reschedules and cancels the daily reminder',
    (_) async {
      final plugin = FlutterLocalNotificationsPlugin();
      final scheduler = LocalNotificationsReminderScheduler(
        notifications: PluginReminderNotifications(plugin: plugin),
      );
      const id = LocalNotificationsReminderScheduler.notificationId;
      Future<List<PendingNotificationRequest>> pending() async =>
          (await plugin.pendingNotificationRequests())
              .where((r) => r.id == id)
              .toList();

      await scheduler.cancel();
      expect(await pending(), isEmpty);

      await scheduler.scheduleDaily(19 * 60);
      final first = await pending();
      expect(first, hasLength(1));
      expect(first.single.title, LocalNotificationsReminderScheduler.title);
      expect(first.single.body, LocalNotificationsReminderScheduler.body);

      await scheduler.scheduleDaily(7 * 60 + 30);
      expect(await pending(), hasLength(1));

      await scheduler.cancel();
      expect(await pending(), isEmpty);
    },
    skip: Platform.isIOS, // needs the user to allow notifications first
  );
}
