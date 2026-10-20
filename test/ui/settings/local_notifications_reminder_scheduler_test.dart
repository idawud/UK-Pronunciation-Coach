import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/ui/settings/local_notifications_reminder_scheduler.dart';
import 'package:uk_pronunciation_coach/ui/settings/reminder_scheduler.dart';

import '../progress/u4_harness.dart';

/// Records what the scheduler asks of the plug-in.
class FakeNotifications implements ReminderNotifications {
  FakeNotifications({
    this.zone = 'Europe/London',
    this.allow = true,
    this.failInit = false,
  });

  String zone;
  bool allow;
  bool failInit;
  int initCount = 0;
  final List<(int, tz.TZDateTime, String, String)> scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<void> initialize() async {
    initCount++;
    if (failInit) throw PlatformException(code: 'init');
  }

  @override
  Future<String> localTimeZone() async => zone;

  @override
  Future<bool> requestPermission() async => allow;

  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime first,
  }) async => scheduled.add((id, first, title, body));

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('nextReminder', () {
    tz.Location london() => tz.getLocation('Europe/London');

    test('later today when the time is still ahead', () {
      final now = tz.TZDateTime(london(), 2026, 7, 1, 8, 0);
      final next = LocalNotificationsReminderScheduler.nextReminder(
        19 * 60,
        now,
      );
      expect(next, tz.TZDateTime(london(), 2026, 7, 1, 19, 0));
      expect(next.toUtc(), DateTime.utc(2026, 7, 1, 18, 0)); // BST = UTC+1
    });

    test('tomorrow when the time has passed or is now', () {
      final now = tz.TZDateTime(london(), 2026, 7, 1, 19, 0);
      expect(
        LocalNotificationsReminderScheduler.nextReminder(19 * 60, now),
        tz.TZDateTime(london(), 2026, 7, 2, 19, 0),
      );
    });

    test('keeps the wall-clock time when BST ends (October)', () {
      // Clocks go back at 02:00 BST on Sunday 25 October 2026.
      final now = tz.TZDateTime(london(), 2026, 10, 24, 20, 0);
      final next = LocalNotificationsReminderScheduler.nextReminder(
        19 * 60,
        now,
      );
      expect(next.hour, 19);
      expect(next.day, 25);
      expect(next.toUtc(), DateTime.utc(2026, 10, 25, 19, 0)); // GMT
      // Adding 24 hours would have given 18:00 GMT.
      expect(next.difference(now), const Duration(hours: 24));
    });

    test('keeps the wall-clock time when BST starts (March)', () {
      // Clocks go forward at 01:00 GMT on Sunday 28 March 2027.
      final now = tz.TZDateTime(london(), 2027, 3, 27, 20, 0);
      final next = LocalNotificationsReminderScheduler.nextReminder(
        19 * 60,
        now,
      );
      expect(next.hour, 19);
      expect(next.toUtc(), DateTime.utc(2027, 3, 28, 18, 0)); // BST
      expect(next.difference(now), const Duration(hours: 22));
    });

    test('a time skipped by the clock change still lands that day', () {
      final now = tz.TZDateTime(london(), 2027, 3, 27, 20, 0);
      final next = LocalNotificationsReminderScheduler.nextReminder(90, now);
      expect(next.day, 28);
      expect(next.isAfter(now), isTrue);
    });

    test('month and year roll over', () {
      final now = tz.TZDateTime(london(), 2026, 12, 31, 23, 30);
      expect(
        LocalNotificationsReminderScheduler.nextReminder(7 * 60, now),
        tz.TZDateTime(london(), 2027, 1, 1, 7, 0),
      );
    });

    test('rejects minutes outside the day', () {
      final now = tz.TZDateTime(london(), 2026, 7, 1);
      expect(
        () => LocalNotificationsReminderScheduler.nextReminder(24 * 60, now),
        throwsRangeError,
      );
      expect(
        () => LocalNotificationsReminderScheduler.nextReminder(-1, now),
        throwsRangeError,
      );
    });
  });

  group('LocalNotificationsReminderScheduler', () {
    late FakeNotifications plugin;
    var now = DateTime.utc(2026, 10, 24, 19, 0); // 20:00 BST

    LocalNotificationsReminderScheduler make() =>
        LocalNotificationsReminderScheduler(
          notifications: plugin,
          now: () => now,
        );

    setUp(() {
      plugin = FakeNotifications();
      now = DateTime.utc(2026, 10, 24, 19, 0);
    });

    test('is supported and initialises lazily, once', () async {
      final s = make();
      expect(s.isSupported, isTrue);
      expect(plugin.initCount, 0);
      await s.requestPermission();
      await s.scheduleDaily(19 * 60);
      await s.cancel();
      expect(plugin.initCount, 1);
    });

    test('schedules in the device time zone across the GMT change', () async {
      await make().scheduleDaily(19 * 60);
      final (id, first, title, body) = plugin.scheduled.single;
      expect(id, LocalNotificationsReminderScheduler.notificationId);
      expect(first.location.name, 'Europe/London');
      expect(first.toUtc(), DateTime.utc(2026, 10, 25, 19, 0));
      expect(title, LocalNotificationsReminderScheduler.title);
      expect(body, LocalNotificationsReminderScheduler.body);
    });

    test('uses another device zone', () async {
      plugin.zone = 'America/New_York';
      now = DateTime.utc(2026, 7, 1, 12, 0); // 08:00 EDT
      await make().scheduleDaily(9 * 60);
      expect(plugin.scheduled.single.$2.toUtc(), DateTime.utc(2026, 7, 1, 13));
    });

    test('falls back to the current offset for an unknown zone', () async {
      plugin.zone = 'Nowhere/Atlantis';
      now = DateTime(2026, 7, 1, 8, 0);
      await make().scheduleDaily(9 * 60);
      final first = plugin.scheduled.single.$2;
      expect(first.location.name, 'Local');
      expect(first.timeZoneOffset, DateTime(2026, 7, 1, 8, 0).timeZoneOffset);
    });

    test('rescheduling replaces the same notification', () async {
      final s = make();
      await s.scheduleDaily(8 * 60);
      await s.scheduleDaily(21 * 60);
      expect(plugin.scheduled.map((e) => e.$1).toSet(), {
        LocalNotificationsReminderScheduler.notificationId,
      });
      expect(plugin.scheduled.last.$2.hour, 21);
    });

    test('cancel cancels the reminder id', () async {
      await make().cancel();
      expect(plugin.cancelled, [
        LocalNotificationsReminderScheduler.notificationId,
      ]);
    });

    test('permission denied is reported', () async {
      plugin.allow = false;
      expect(await make().requestPermission(), isFalse);
      plugin.allow = true;
      expect(await make().requestPermission(), isTrue);
    });

    test('a failed initialisation is retried next time', () async {
      plugin.failInit = true;
      final s = make();
      await expectLater(s.scheduleDaily(60), throwsA(isA<PlatformException>()));
      plugin.failInit = false;
      await s.scheduleDaily(60);
      expect(plugin.initCount, 2);
      expect(plugin.scheduled, hasLength(1));
    });
  });

  group('PluginReminderNotifications (mocked platform channels)', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    const tzChannel = MethodChannel('flutter_timezone');
    late List<MethodCall> calls;
    late Object? permissionResult;

    setUp(() {
      calls = [];
      permissionResult = true;
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'initialize' => true,
          'requestNotificationsPermission' => permissionResult,
          _ => null,
        };
      });
      messenger.setMockMethodCallHandler(
        tzChannel,
        (call) async => 'Europe/London',
      );
    });

    tearDown(() {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(tzChannel, null);
    });

    test(
      'initialises, asks, schedules an inexact daily reminder, cancels',
      () async {
        final s = LocalNotificationsReminderScheduler(
          notifications: PluginReminderNotifications(),
          now: () => DateTime.utc(2026, 10, 24, 19),
        );
        expect(await s.requestPermission(), isTrue);
        await s.scheduleDaily(19 * 60);
        await s.cancel();

        expect(calls.map((c) => c.method), [
          'initialize',
          'requestNotificationsPermission',
          'zonedSchedule',
          'cancel',
        ]);
        final init = calls.first.arguments as Map;
        expect(init['defaultIcon'], '@mipmap/ic_launcher');

        final args = (calls[2].arguments as Map).cast<String, Object?>();
        expect(args['id'], LocalNotificationsReminderScheduler.notificationId);
        expect(args['title'], LocalNotificationsReminderScheduler.title);
        expect(args['timeZoneName'], 'Europe/London');
        expect(args['scheduledDateTime'], startsWith('2026-10-25T19:00'));
        expect(args['matchDateTimeComponents'], DateTimeComponents.time.index);
        final android = (args['platformSpecifics'] as Map)
            .cast<String, Object?>();
        expect(
          android['scheduleMode'],
          AndroidScheduleMode.inexactAllowWhileIdle.name,
        );
        expect(android['channelId'], PluginReminderNotifications.channelId);
        expect((calls[3].arguments as Map)['id'], 1);
      },
    );

    test('a null permission answer counts as denied', () async {
      permissionResult = null;
      final n = PluginReminderNotifications();
      await n.initialize();
      expect(await n.requestPermission(), isFalse);
      expect(await n.localTimeZone(), 'Europe/London');
    });
  });

  group('platformReminderScheduler', () {
    test('local notifications on phones, unavailable elsewhere', () {
      expect(
        platformReminderScheduler(mobile: true),
        isA<LocalNotificationsReminderScheduler>(),
      );
      expect(
        platformReminderScheduler(mobile: false),
        isA<UnavailableReminderScheduler>(),
      );
      // The test host is not a phone.
      expect(platformReminderScheduler(), isA<UnavailableReminderScheduler>());
      expect(
        ProviderContainer().read(reminderSchedulerProvider),
        isA<UnavailableReminderScheduler>(),
      );
    });
  });

  group('reminderRestoreProvider', () {
    Future<RecordingReminderScheduler> restore(
      UserProfile profile, {
      bool supported = true,
      bool fail = false,
    }) async {
      final repo = FakeProgressRepository(clock: testClock);
      await repo.saveProfile(profile);
      final reminders = RecordingReminderScheduler(
        supported: supported,
        fail: fail,
      );
      final container = ProviderContainer(
        overrides: [
          progressRepositoryProvider.overrideWithValue(repo),
          reminderSchedulerProvider.overrideWithValue(reminders),
        ],
      );
      addTearDown(container.dispose);
      await container.read(reminderRestoreProvider.future);
      return reminders;
    }

    test('re-schedules the saved reminder', () async {
      final r = await restore(const UserProfile(reminderMinutes: 480));
      expect(r.scheduled, [480]);
    });

    test('does nothing when the reminder is off or unsupported', () async {
      expect((await restore(const UserProfile())).scheduled, isEmpty);
      final r = await restore(
        const UserProfile(reminderMinutes: 480),
        supported: false,
      );
      expect(r.scheduled, isEmpty);
    });

    test('never throws', () async {
      final r = await restore(
        const UserProfile(reminderMinutes: 480),
        fail: true,
      );
      expect(r.scheduled, isEmpty);
    });
  });
}
