# Contract and native requests: U4-progress

No change to `lib/core/contracts/` or `lib/core/models/` is needed. These requests are
for files U4 does not own (CI allowlist, `android/`, `ios/`, `lib/core/providers.dart`).

## 1. Allow `dbus` (MPL-2.0) so reminders can use flutter_local_notifications: DONE

**Done 2026-10-20** (feat/reminders-mpl): owner-approved; `dbus` and `nm` are in
`tools/ci/licence_allowlist.txt` and `LocalNotificationsReminderScheduler` is the
default on Android / iOS. See docs/handoff/U4-progress.md.

**What:** add `dbus  # MPL-2.0, Linux-only transitive of flutter_local_notifications_linux / file_picker_linux; not built into the Android or iOS app` to `tools/ci/licence_allowlist.txt` (W0 owns it).

**Why:** `flutter_local_notifications` (BSD-3) always depends on
`flutter_local_notifications_linux`, which depends on `dbus` 0.8.0 (MPL-2.0).
`check_licences.py` reads the MPL text (it names the GNU Affero licence as a
"Secondary License") as AGPL and fails. No version of the plug-in avoids it, and the
other Flutter notification plug-in (`awesome_notifications`) pulls a closed Android
core library from Maven, so I did not use it. MPL-2.0 is file-level copyleft and
only the Linux desktop build would compile it; the app ships on Android and iOS only.

**Until then:** reminders go through `ReminderScheduler`
(`lib/ui/settings/reminder_scheduler.dart`). The default
`UnavailableReminderScheduler` reports `isSupported == false`, and Settings shows the
reminder switch disabled with "Reminders are not available in this version yet."
(The reminder time in `UserProfile.reminderMinutes` is still exported and imported.)

**After approval (U4 or I1):** `flutter pub add flutter_local_notifications timezone
flutter_timezone`, add an implementation like this in `lib/ui/settings/`, and bind it
in `reminderSchedulerProvider` (or override in `lib/core/providers.dart`):

```dart
class LocalNotificationsReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  static const _id = 1;
  bool get isSupported => true;
  Future<void> _init() async { /* plugin.initialize(InitializationSettings(android:
    AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings(
    requestAlertPermission: false))); tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone())); */ }
  Future<bool> requestPermission() async { /* Android: requestNotificationsPermission();
    iOS: requestPermissions(alert: true, sound: true) */ }
  Future<void> scheduleDaily(int m) async { /* zonedSchedule(_id, 'Time to practise',
    'A few minutes of reading keeps your streak going.', next tz time at m,
    NotificationDetails(android: AndroidNotificationDetails('daily_reminder',
    'Daily reminder')), androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time) */ }
  Future<void> cancel() => _plugin.cancel(_id);
}
```

Use **inexact** alarms: a practice reminder does not need `SCHEDULE_EXACT_ALARM`.

## 2. Native setup for notifications (R1 / I1, after request 1): DONE

**Done 2026-10-20**: desugaring (`desugar_jdk_libs` 2.1.4, GPL-2.0 with Classpath
Exception, flagged in docs/licences.md), boot permission and receivers, iOS delegate.

- Android `android/app/build.gradle(.kts)`: `isCoreLibraryDesugaringEnabled = true`
  and `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.x")`
  (required by flutter_local_notifications).
- Android manifest: `POST_NOTIFICATIONS` is already declared by W0. For reminders to
  survive a reboot add `RECEIVE_BOOT_COMPLETED` and the plug-in's
  `ScheduledNotificationBootReceiver` / `ScheduledNotificationReceiver` receivers.
  No `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`.
- iOS `AppDelegate.swift`: set `UNUserNotificationCenter.current().delegate` as in the
  plug-in README so the reminder shows while the app is open.

## 3. File save / pick (export and import): registration confirmed

**2026-10-20**: the generated Dart plug-in registrant registers both implementations
without `file_picker`; kept as is (see the U4 handoff). The save / open round trip
still needs a device.

`BackupFiles` (`lib/ui/settings/backup_files.dart`) uses file_picker's federated
packages directly (`file_picker_platform_interface`, `android_file_picker`,
`file_picker_darwin`, all MIT) instead of `file_picker`, whose `file_picker_linux`
also depends on `dbus`. Android save uses the Storage Access Framework
(`ACTION_CREATE_DOCUMENT`) and open uses `ACTION_GET_CONTENT` / `ACTION_OPEN_DOCUMENT`; the package declares no permissions, so no storage
permission or FileProvider needed. iOS uses `UIDocumentPickerViewController`: no
Info.plist keys needed. **Needs on-device verification** (not possible here): that both
implementations register through `dartPluginClass` without the `file_picker` app
package, and that saving a `.json` with `application/json` works on both platforms.
If not, add `file_picker` once request 1 is approved.

## 4. Wiring (I1): reminder part DONE

**2026-10-20**: `reminderRestoreProvider` re-schedules on start-up (listened to in
`CoachApp`). The other bullets are unchanged.

- `reminderSchedulerProvider` and `backupFilesProvider` live in
  `lib/ui/settings/`. I1 may bind them from `lib/core/providers.dart` instead.
- On app start, if `profile.reminderMinutes != null`, call
  `scheduleDaily(reminderMinutes)` once (e.g. after an OS restore) — U4 only schedules
  when the user changes the setting or imports a backup.
- `ProgressRepository.deleteAll()` resets `onboardingDone`, so after "Delete all data"
  the router should send the user to onboarding on next start (U1 / I1).
- Text size (`UserProfile.textScale`) is saved here; U2 / U3 apply it to passage text.
- `docs/licences.md` and `lib/ui/settings/licence_data.dart` must stay in step;
  `test/ui/settings/licences_screen_test.dart` checks the main components.
  A2's request 3 (ONNX Runtime row) is already shown on the Licences page.
