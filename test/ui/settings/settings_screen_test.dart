import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uk_pronunciation_coach/core/contracts/navigation.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/ui/settings/licences_screen.dart';
import 'package:uk_pronunciation_coach/ui/settings/settings_providers.dart';
import 'package:uk_pronunciation_coach/ui/settings/settings_screen.dart';

import '../progress/u4_harness.dart';

Future<void> tall(WidgetTester tester) async {
  tester.view.physicalSize = const Size(600, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  late FakeProgressRepository repo;
  late RecordingReminderScheduler reminders;
  late MemoryBackupFiles files;
  late FakePhonemeRecognizer recognizer;
  late FakeVoiceService voice;

  setUp(() {
    repo = FakeProgressRepository(clock: testClock);
    reminders = RecordingReminderScheduler();
    files = MemoryBackupFiles();
    recognizer = FakePhonemeRecognizer();
    voice = FakeVoiceService();
  });

  Future<void> pump(WidgetTester tester, {Widget? child}) async {
    await tall(tester);
    await tester.pumpWidget(
      testApp(
        child ?? const SettingsScreen(),
        overrides: overridesFor(
          repo: repo,
          recognizer: recognizer,
          voice: voice,
          reminders: reminders,
          files: files,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<UserProfile> profile(WidgetTester tester) async =>
      (await tester.runAsync(repo.profile))!;

  testWidgets('loading and error states', (tester) async {
    await tester.pumpWidget(
      testApp(
        const SettingsScreen(),
        overrides: [
          ...overridesFor(repo: repo),
          userProfileProvider.overrideWith((ref) => never()),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    var calls = 0;
    await tester.pumpWidget(
      testApp(
        const SettingsScreen(),
        overrides: [
          ...overridesFor(repo: repo),
          userProfileProvider.overrideWith((ref) async {
            calls++;
            throw StateError('db');
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Your settings couldn't be loaded."), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, greaterThanOrEqualTo(2));
  });

  testWidgets('changes the daily goal', (tester) async {
    await pump(tester);
    await tester.tap(find.text('10 min'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20 min').last);
    await tester.pumpAndSettle();
    expect((await profile(tester)).dailyGoalMinutes, 20);
    expect(find.text('20 min'), findsOneWidget);
  });

  testWidgets('switches the reminder on, changes the time, and off', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Daily reminder'));
    await tester.pumpAndSettle();
    expect(reminders.scheduled, [defaultReminderMinutes]);
    expect((await profile(tester)).reminderMinutes, defaultReminderMinutes);

    await tester.tap(find.text('Reminder time'));
    await tester.pumpAndSettle();
    expect(find.text('Daily reminder'), findsWidgets); // picker help text
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(reminders.scheduled.length, 2);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(reminders.cancelCount, 1);
    expect((await profile(tester)).reminderMinutes, isNull);
  });

  testWidgets('time picker cancel keeps the reminder', (tester) async {
    await tester.runAsync(
      () => repo.saveProfile(const UserProfile(reminderMinutes: 480)),
    );
    await pump(tester);
    expect(find.text('8:00 AM'), findsOneWidget);
    await tester.tap(find.text('Reminder time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(reminders.scheduled, isEmpty);
  });

  testWidgets('denied notification permission leaves the reminder off', (
    tester,
  ) async {
    reminders.allow = false;
    await pump(tester);
    await tester.tap(find.text('Daily reminder'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Notifications are off'), findsOneWidget);
    expect(reminders.scheduled, isEmpty);
    expect((await profile(tester)).reminderMinutes, isNull);
  });

  testWidgets('a failing scheduler shows a message and keeps the setting', (
    tester,
  ) async {
    reminders = RecordingReminderScheduler(fail: true);
    await pump(tester);
    await tester.tap(find.text('Daily reminder'));
    await tester.pumpAndSettle();
    expect(find.textContaining("couldn't be set"), findsOneWidget);
    expect((await profile(tester)).reminderMinutes, isNull);
  });

  testWidgets('a failing scheduler keeps the old reminder time', (
    tester,
  ) async {
    await tester.runAsync(
      () => repo.saveProfile(const UserProfile(reminderMinutes: 480)),
    );
    reminders = RecordingReminderScheduler(fail: true);
    await pump(tester);
    await tester.tap(find.text('Reminder time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining("couldn't be set"), findsOneWidget);
    expect((await profile(tester)).reminderMinutes, 480);
  });

  testWidgets('switching off still works when cancelling fails', (
    tester,
  ) async {
    await tester.runAsync(
      () => repo.saveProfile(const UserProfile(reminderMinutes: 480)),
    );
    reminders = RecordingReminderScheduler(fail: true);
    await pump(tester);
    await tester.tap(find.text('Daily reminder'));
    await tester.pumpAndSettle();
    expect(reminders.cancelCount, 1);
    expect((await profile(tester)).reminderMinutes, isNull);
  });

  testWidgets('reminder is disabled when unsupported', (tester) async {
    reminders = RecordingReminderScheduler(supported: false);
    await pump(tester);
    expect(find.textContaining('available on Android and iOS'), findsOneWidget);
    final tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Daily reminder'),
    );
    expect(tile.onChanged, isNull);
  });

  testWidgets('text size slider saves on release', (tester) async {
    await pump(tester);
    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect((await profile(tester)).textScale, greaterThan(1.0));
  });

  testWidgets('keep recordings toggle', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Keep recordings'));
    await tester.pumpAndSettle();
    expect((await profile(tester)).keepRecordings, isTrue);
  });

  group('model tier', () {
    testWidgets('downloads the full model with progress, then selects it', (
      tester,
    ) async {
      recognizer = FakePhonemeRecognizer(
        stepDelay: const Duration(milliseconds: 10),
      );
      await pump(tester);
      expect(find.text('Download full model (320 MB)'), findsOneWidget);
      final full = tester.widget<SegmentedButton<Object>>(
        find.byWidgetPredicate((w) => w is SegmentedButton),
      );
      expect(full.segments.last.enabled, isFalse);

      await tester.tap(find.text('Download full model (320 MB)'));
      await tester.pump(const Duration(milliseconds: 15));
      await tester.pump();
      expect(find.textContaining('Downloading: '), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();
      expect(find.text('Full model on this phone (320 MB)'), findsOneWidget);

      await tester.tap(find.text('Full'));
      await tester.pumpAndSettle();
      expect((await profile(tester)).tierOverride, ModelTier.full);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect((await profile(tester)).tierOverride, ModelTier.light);
      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();
      expect((await profile(tester)).tierOverride, isNull);
    });

    testWidgets('cancel pauses and resume continues', (tester) async {
      recognizer = FakePhonemeRecognizer(
        stepDelay: const Duration(milliseconds: 10),
      );
      await pump(tester);
      await tester.tap(find.text('Download on Wi-Fi only'));
      await tester.pump();
      await tester.tap(find.text('Download full model (320 MB)'));
      await tester.pump(const Duration(milliseconds: 15));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(find.textContaining('Paused at'), findsOneWidget);
      expect(find.text('Resume download'), findsOneWidget);
    });

    testWidgets('shows waiting for Wi-Fi and verifying', (tester) async {
      await pump(tester);
      for (final (state, text) in [
        (DownloadState.waitingForWifi, 'Waiting for Wi-Fi…'),
        (DownloadState.verifying, 'Checking the download…'),
      ]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          testApp(
            const SettingsScreen(),
            overrides: [
              ...overridesFor(repo: repo, recognizer: recognizer),
              modelDownloadProvider.overrideWithValue(
                AsyncData(ModelDownloadProgress(state: state, totalBytes: 1)),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text(text), findsOneWidget);
      }
    });

    testWidgets('a failed download offers a retry', (tester) async {
      recognizer = FakePhonemeRecognizer(failDownload: true);
      await pump(tester);
      await tester.tap(find.text('Download full model (320 MB)'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('The download failed: Checksum mismatch'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('deletes the full model after confirming', (tester) async {
      recognizer = FakePhonemeRecognizer(fullAvailable: true);
      await tester.runAsync(
        () => repo.saveProfile(const UserProfile(tierOverride: ModelTier.full)),
      );
      await pump(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(recognizer.fullAvailable, isTrue);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();
      expect(recognizer.fullAvailable, isFalse);
      expect((await profile(tester)).tierOverride, isNull);
      expect(find.text('Download full model (320 MB)'), findsOneWidget);
    });
  });

  group('British voice', () {
    testWidgets('plays a sample when a voice is installed', (tester) async {
      await pump(tester);
      expect(find.text('British voice ready'), findsOneWidget);
      expect(find.text('English (United Kingdom)'), findsOneWidget);
      await tester.tap(find.text('Play a sample'));
      await tester.pump();
      expect(voice.spoken.single.$1, contains('British'));
    });

    testWidgets('explains how to install a voice when missing', (tester) async {
      voice = FakeVoiceService(britishVoice: false);
      await pump(tester);
      expect(find.text('No British voice found'), findsOneWidget);
      expect(find.textContaining('On Android:'), findsOneWidget);
      voice.britishVoice = true;
      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();
      expect(find.text('British voice ready'), findsOneWidget);
    });

    testWidgets('iOS guidance', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      voice = FakeVoiceService(britishVoice: false);
      await pump(tester);
      expect(find.textContaining('On iPhone:'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('loading and error', (tester) async {
      await tall(tester);
      await tester.pumpWidget(
        testApp(
          const SettingsScreen(),
          overrides: [
            ...overridesFor(repo: repo),
            voiceStatusProvider.overrideWith((ref) => never()),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Checking for a British voice…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await tester.pumpWidget(
        testApp(
          const SettingsScreen(),
          overrides: [
            ...overridesFor(repo: repo),
            voiceStatusProvider.overrideWith(
              (ref) async => throw StateError('tts'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Couldn't check the voice"), findsOneWidget);
    });
  });

  group('your data', () {
    testWidgets('exports progress to a dated file', (tester) async {
      await tester.runAsync(
        () => repo.saveProfile(const UserProfile(level: 4)),
      );
      await pump(tester);
      await tester.tap(find.text('Export progress'));
      await tester.pumpAndSettle();
      final json = files.saved['uk-coach-progress-2026-10-19.json']!;
      expect(
        ProgressBackup.fromJson(jsonDecode(json) as Map<String, dynamic>)
            .profile
            .level,
        4,
      );
      expect(find.textContaining('Progress saved'), findsOneWidget);
    });

    testWidgets('export cancelled or failing', (tester) async {
      files.cancelSave = true;
      await pump(tester);
      await tester.tap(find.text('Export progress'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      files.fail = true;
      await tester.tap(find.text('Export progress'));
      await tester.pumpAndSettle();
      expect(find.textContaining("couldn't be saved"), findsOneWidget);
    });

    testWidgets('imports a backup after confirming', (tester) async {
      final source = FakeProgressRepository(clock: testClock);
      await source.saveProfile(
        const UserProfile(level: 5, reminderMinutes: 600),
      );
      files.toPick = await source.exportJson();
      await pump(tester);
      await tester.tap(find.text('Import progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await profile(tester)).level, 1);

      await tester.tap(find.text('Import progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      expect((await profile(tester)).level, 5);
      expect(reminders.scheduled, [600]);
      expect(find.text('Progress imported.'), findsOneWidget);
    });

    testWidgets('import without a reminder cancels it', (tester) async {
      files.toPick = await FakeProgressRepository(clock: testClock)
          .exportJson();
      await pump(tester);
      await tester.tap(find.text('Import progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      expect(reminders.cancelCount, 1);
    });

    testWidgets('rejects a file that is not a backup', (tester) async {
      files.toPick = '{"hello": 1}';
      await pump(tester);
      await tester.tap(find.text('Import progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      expect(find.textContaining("isn't a progress backup"), findsOneWidget);
    });

    testWidgets('import picker cancelled or failing', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Import progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      files.fail = true;
      await tester.tap(find.text('Import progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      expect(find.textContaining("couldn't be imported"), findsOneWidget);
    });

    testWidgets('deletes all data after confirming', (tester) async {
      await tester.runAsync(() async {
        await repo.saveProfile(const UserProfile(level: 3));
        await repo.saveAttempt(cannedRiverAttempt);
      });
      await pump(tester);
      await tester.tap(find.text('Delete all data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await profile(tester)).level, 3);

      await tester.tap(find.text('Delete all data'));
      await tester.pumpAndSettle();
      expect(find.text('Delete all your data?'), findsOneWidget);
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();
      expect((await profile(tester)).level, 1);
      expect(await tester.runAsync(() => repo.attempts()), isEmpty);
      expect(reminders.cancelCount, 1);
      expect(find.text('All your data was deleted.'), findsOneWidget);
    });

    testWidgets('deletes all data even when cancelling the reminder fails', (
      tester,
    ) async {
      await tester.runAsync(
        () => repo.saveProfile(const UserProfile(level: 3)),
      );
      reminders = RecordingReminderScheduler(fail: true);
      await pump(tester);
      await tester.tap(find.text('Delete all data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();
      expect((await profile(tester)).level, 1);
      expect(find.text('All your data was deleted.'), findsOneWidget);
    });
  });

  group('licences link', () {
    testWidgets('opens the licences page without a router', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Licences'));
      await tester.pumpAndSettle();
      expect(find.byType(LicencesScreen), findsOneWidget);
    });

    testWidgets('pushes the licences route with a router', (tester) async {
      await tall(tester);
      final router = GoRouter(
        initialLocation: AppRoutes.settings,
        routes: [
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, _) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'licences',
                builder: (_, _) => const Text('licences route'),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overridesFor(repo: repo),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Licences'));
      await tester.pumpAndSettle();
      expect(find.text('licences route'), findsOneWidget);
    });
  });

  test('formatMegabytes', () {
    expect(formatMegabytes(320 * 1024 * 1024), '320 MB');
  });
}
