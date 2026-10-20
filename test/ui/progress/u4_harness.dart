// Shared test setup for U4-progress widget and golden tests: seeded fakes, provider
// overrides and a test app wrapper.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/ui/settings/backup_files.dart';
import 'package:uk_pronunciation_coach/ui/settings/reminder_scheduler.dart';
import 'package:uk_pronunciation_coach/ui/theme/app_theme.dart';

/// Fixed "now" for every U4 test: Monday 19 October 2026, noon.
final DateTime testNow = DateTime(2026, 10, 19, 12);

/// Clock returning [testNow].
DateTime testClock() => testNow;

/// A repository with two weeks of practice: 8 readings with rising scores, sound
/// stats, practice sessions (streak of 4) and one level change.
Future<FakeProgressRepository> seededRepository() async {
  final repo = FakeProgressRepository(clock: testClock);
  final engine = FakePracticeEngine(
    content: FakeContentRepository(),
    progress: repo,
    clock: testClock,
  );
  const days = [13, 11, 9, 7, 5, 3, 1, 0];
  const scores = [58, 64, 61, 70, 74, 79, 83, 88];
  for (var i = 0; i < days.length; i++) {
    final at = testNow.subtract(Duration(days: days[i], hours: 2));
    final attempt = i == 2
        ? cannedRiverAttempt.copyWith(id: 'a$i', at: at)
        : goodAttempt(riverPassage, id: 'a$i', at: at, score: scores[i]);
    await repo.saveAttempt(attempt);
    await repo.logPractice(
      PracticeSession(start: at, duration: const Duration(minutes: 6)),
    );
  }
  await repo.logPractice(
    PracticeSession(
      start: testNow.subtract(const Duration(days: 2)),
      duration: const Duration(minutes: 5),
    ),
  );
  await repo.saveLevelChange(
    LevelChange(
      from: 1,
      to: 2,
      reason: 'Three passages in a row at 85 or more: welcome to level 2.',
      at: testNow.subtract(const Duration(days: 4)),
    ),
  );
  final daily = await engine.dailyProgress();
  await repo.saveProfile(
    const UserProfile(
      level: 2,
      dailyGoalMinutes: 10,
      onboardingDone: true,
    ).copyWith(streak: daily.streak, reminderMinutes: 19 * 60 + 30),
  );
  return repo;
}

/// Records calls instead of scheduling notifications.
class RecordingReminderScheduler implements ReminderScheduler {
  RecordingReminderScheduler({
    this.supported = true,
    this.allow = true,
    this.fail = false,
  });

  final bool supported;
  bool allow;

  /// When true, every call throws (e.g. the plug-in failed).
  bool fail;
  final List<int> scheduled = [];
  int cancelCount = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<bool> requestPermission() async {
    if (fail) throw Exception('plug-in failed');
    return allow;
  }

  @override
  Future<void> scheduleDaily(int minutesAfterMidnight) async {
    if (fail) throw Exception('plug-in failed');
    scheduled.add(minutesAfterMidnight);
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    if (fail) throw Exception('plug-in failed');
  }
}

/// In-memory backup files: [saved] holds what was saved; [toPick] is returned by pick.
class MemoryBackupFiles implements BackupFiles {
  MemoryBackupFiles({this.toPick, this.cancelSave = false, this.fail = false});

  String? toPick;
  bool cancelSave;
  bool fail;
  final Map<String, String> saved = {};

  @override
  Future<bool> save(String fileName, String contents) async {
    if (fail) throw Exception('disk full');
    if (cancelSave) return false;
    saved[fileName] = contents;
    return true;
  }

  @override
  Future<String?> pick() async {
    if (fail) throw Exception('unreadable');
    return toPick;
  }
}

/// Provider overrides for U4 screens.
List<Override> overridesFor({
  required FakeProgressRepository repo,
  FakePhonemeRecognizer? recognizer,
  FakeVoiceService? voice,
  ReminderScheduler? reminders,
  BackupFiles? files,
}) => [
  clockProvider.overrideWithValue(testClock),
  progressRepositoryProvider.overrideWithValue(repo),
  phonemeRecognizerProvider.overrideWithValue(
    recognizer ?? FakePhonemeRecognizer(),
  ),
  voiceServiceProvider.overrideWithValue(voice ?? FakeVoiceService()),
  reminderSchedulerProvider.overrideWithValue(
    reminders ?? RecordingReminderScheduler(),
  ),
  backupFilesProvider.overrideWithValue(files ?? MemoryBackupFiles()),
];

/// [child] in a [ProviderScope] with [overrides] and the app theme.
Widget testApp(
  Widget child, {
  required List<Override> overrides,
  Brightness brightness = Brightness.light,
  ThemeData Function(ThemeData)? wrapTheme,
}) {
  final base = brightness == Brightness.light
      ? AppTheme.light()
      : AppTheme.dark();
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: wrapTheme == null ? base : wrapTheme(base),
      home: child,
    ),
  );
}

/// A future that never completes (loading states).
Future<T> never<T>() => Completer<T>().future;
