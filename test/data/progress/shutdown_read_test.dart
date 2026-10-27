import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/data/data.dart';
import 'package:uk_pronunciation_coach/ui/settings/reminder_scheduler.dart';

import '../../ui/progress/u4_harness.dart';

/// Holds every select until [gate] opens, then fails it with [error]
/// (by default the way a closed drift channel does).
class _FailingSelects extends QueryInterceptor {
  _FailingSelects(this.gate, {Object? error}) : error = error ?? channelClosed;
  final Completer<void> gate;
  final Object error;
  final started = Completer<void>();

  /// What drift's internal `ConnectionClosedException` reports when the channel
  /// goes away; the repository recognises it as shutdown, not a query failure.
  static final channelClosed = StateError(
    'Channel was closed before receiving a response',
  );

  /// A genuine failure while the store is open.
  static final diskError = StateError('database disk image is malformed');

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (!started.isCompleted) started.complete();
    await gate.future;
    throw error;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  DriftProgressRepository repoWith(_FailingSelects interceptor) =>
      DriftProgressRepository(
        ProgressDatabase(NativeDatabase.memory().interceptWith(interceptor)),
      );

  test(
    'a profile read cut off by close() returns the default profile',
    () async {
      final selects = _FailingSelects(Completer());
      final repo = repoWith(selects);
      final read = repo.profile();
      await selects.started.future;
      final closing = repo.close();
      selects.gate.complete();
      expect(await read, const UserProfile());
      await closing;
    },
  );

  test(
    'a profile read that fails while the store is open still throws',
    () async {
      final selects = _FailingSelects(
        Completer(),
        error: _FailingSelects.diskError,
      );
      final repo = repoWith(selects);
      final read = repo.profile();
      await selects.started.future;
      selects.gate.complete();
      await expectLater(read, throwsA(isA<StateError>()));
      await repo.close();
    },
  );

  test(
    'reminder restore cut off by shutdown leaks no uncaught error',
    () async {
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        final selects = _FailingSelects(Completer());
        final repo = repoWith(selects);
        final reminders = RecordingReminderScheduler(supported: true);
        final container = ProviderContainer(
          overrides: [
            progressRepositoryProvider.overrideWithValue(repo),
            reminderSchedulerProvider.overrideWithValue(reminders),
          ],
        );
        final restore = container.read(reminderRestoreProvider.future);
        await selects.started.future;
        // What the app does on shutdown: the store closes, then the scope goes.
        final closing = repo.close();
        selects.gate.complete();
        await restore; // completes with a value, not an error
        await closing;
        container.dispose();
        await Future<void>.delayed(Duration.zero);
        expect(reminders.scheduled, isEmpty);
      }, (e, _) => uncaught.add(e));
      expect(uncaught, isEmpty);
    },
  );
}
