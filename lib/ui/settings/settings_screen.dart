import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contracts/navigation.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import 'backup_files.dart';
import 'licences_screen.dart';
import 'model_tier_section.dart';
import 'reminder_scheduler.dart';
import 'voice_section.dart';

/// Daily goal choices in minutes.
const List<int> dailyGoalChoices = [5, 10, 15, 20, 30];

/// Reminder time used when the reminder is first switched on (19:00).
const int defaultReminderMinutes = 19 * 60;

/// Text size range (multiplier of the 20 sp passage text).
const double minTextScale = 0.8, maxTextScale = 1.6;

/// Settings: practice (goal, reminder, text size), privacy (keep recordings), scoring
/// model, British voice, your data (export, import, delete) and licences.
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: switch (profile) {
        AsyncData(:final value) => _SettingsBody(profile: value),
        AsyncError() => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Your settings couldn't be loaded.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.invalidate(userProfileProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  const _SettingsBody({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  double? _dragScale;
  bool _busy = false;

  UserProfile get profile => widget.profile;

  Future<void> _update(UserProfile Function(UserProfile p) change) async {
    final repo = ref.read(progressRepositoryProvider);
    await repo.saveProfile(change(await repo.profile()));
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  static const _reminderFailed =
      "The reminder couldn't be set. Please try again.";

  Future<void> _setReminder(bool on) async {
    final scheduler = ref.read(reminderSchedulerProvider);
    if (!on) {
      try {
        await scheduler.cancel();
      } on Exception {
        // Nothing to cancel on this device; still switch the setting off.
      }
      await _update((p) => p.copyWith(reminderMinutes: null));
      return;
    }
    try {
      if (!await scheduler.requestPermission()) {
        _say(
          'Notifications are off for this app. Turn them on in your phone '
          'settings to get reminders.',
        );
        return;
      }
      final minutes = profile.reminderMinutes ?? defaultReminderMinutes;
      await scheduler.scheduleDaily(minutes);
      await _update((p) => p.copyWith(reminderMinutes: minutes));
    } on Exception {
      _say(_reminderFailed);
    }
  }

  Future<void> _pickReminderTime() async {
    final current = profile.reminderMinutes ?? defaultReminderMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: 'Daily reminder',
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    try {
      await ref.read(reminderSchedulerProvider).scheduleDaily(minutes);
    } on Exception {
      _say(_reminderFailed);
      return;
    }
    await _update((p) => p.copyWith(reminderMinutes: minutes));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() => _run(() async {
    try {
      final json = await ref.read(progressRepositoryProvider).exportJson();
      final name = backupFileName(ref.read(clockProvider)());
      final saved = await ref.read(backupFilesProvider).save(name, json);
      if (saved) _say('Progress saved as $name.');
    } on Exception {
      _say("Your progress couldn't be saved. Please try again.");
    }
  });

  Future<void> _import() async {
    final ok = await _confirm(
      title: 'Import progress?',
      body:
          'This replaces all your current progress and settings with the '
          'backup file.',
      action: 'Choose file',
    );
    if (!ok) return;
    await _run(() async {
      try {
        final json = await ref.read(backupFilesProvider).pick();
        if (json == null) return;
        final repo = ref.read(progressRepositoryProvider);
        await repo.importJson(json);
        final minutes = (await repo.profile()).reminderMinutes;
        final scheduler = ref.read(reminderSchedulerProvider);
        if (minutes == null) {
          await scheduler.cancel();
        } else {
          await scheduler.scheduleDaily(minutes);
        }
        _say('Progress imported.');
      } on FormatException {
        _say("That file isn't a progress backup from this app.");
      } on Exception {
        _say("The backup couldn't be imported. Please try again.");
      }
    });
  }

  Future<void> _deleteAll() async {
    final ok = await _confirm(
      title: 'Delete all your data?',
      body:
          'This deletes every reading, score, recording and setting on this '
          'phone. It cannot be undone. Export your progress first if you want '
          'a copy.',
      action: 'Delete everything',
    );
    if (!ok) return;
    await _run(() async {
      try {
        await ref.read(reminderSchedulerProvider).cancel();
      } on Exception {
        // Deleting the data matters more than a stale reminder.
      }
      await ref.read(progressRepositoryProvider).deleteAll();
      _say('All your data was deleted.');
    });
  }

  void _openLicences() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push(AppRoutes.licences);
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const LicencesScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final scheduler = ref.watch(reminderSchedulerProvider);
    final reminderOn = profile.reminderMinutes != null;
    final reminder = profile.reminderMinutes ?? defaultReminderMinutes;
    final scale = _dragScale ?? profile.textScale;
    final goals = {...dailyGoalChoices, profile.dailyGoalMinutes}.toList()
      ..sort();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const _Header('Practice'),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Daily goal'),
              trailing: DropdownButton<int>(
                value: profile.dailyGoalMinutes,
                underline: const SizedBox.shrink(),
                items: [
                  for (final g in goals)
                    DropdownMenuItem(value: g, child: Text('$g min')),
                ],
                onChanged: (g) {
                  if (g != null) {
                    _update((p) => p.copyWith(dailyGoalMinutes: g));
                  }
                },
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Daily reminder'),
              subtitle: Text(
                scheduler.isSupported
                    ? 'A local notification. Nothing is sent anywhere.'
                    : 'Reminders are available on Android and iOS.',
              ),
              value: reminderOn,
              onChanged: scheduler.isSupported || reminderOn
                  ? _setReminder
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Reminder time'),
              enabled: reminderOn && scheduler.isSupported,
              trailing: Text(
                MaterialLocalizations.of(context).formatTimeOfDay(
                  TimeOfDay(hour: reminder ~/ 60, minute: reminder % 60),
                ),
                style: t.bodyLarge,
              ),
              onTap: _pickReminderTime,
            ),
            ListTile(
              leading: const Icon(Icons.format_size),
              title: const Text('Passage text size'),
              trailing: Text('${(scale * 100).round()}%'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Slider(
                    value: scale.clamp(minTextScale, maxTextScale),
                    min: minTextScale,
                    max: maxTextScale,
                    divisions: 8,
                    label: '${(scale * 100).round()}%',
                    semanticFormatterCallback: (v) =>
                        'Text size ${(v * 100).round()} percent',
                    onChanged: (v) => setState(() => _dragScale = v),
                    onChangeEnd: (v) async {
                      await _update((p) => p.copyWith(textScale: v));
                      if (mounted) setState(() => _dragScale = null);
                    },
                  ),
                  Text(
                    'On Thursday we walked by the river.',
                    style: t.bodyLarge?.copyWith(fontSize: 20 * scale),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const _Header('Privacy'),
            SwitchListTile(
              secondary: const Icon(Icons.mic_none),
              title: const Text('Keep recordings'),
              subtitle: const Text(
                'Off: each recording is deleted as soon as it is scored. '
                'Recordings never leave your phone.',
              ),
              value: profile.keepRecordings,
              onChanged: (v) => _update((p) => p.copyWith(keepRecordings: v)),
            ),
            const _Header('Scoring model'),
            ModelTierSection(profile: profile),
            const _Header('British voice'),
            const VoiceSection(),
            const _Header('Your data'),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Export progress'),
              subtitle: const Text(
                'Save a backup file. Recordings are not included.',
              ),
              enabled: !_busy,
              onTap: _export,
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Import progress'),
              subtitle: const Text('Restore from a backup file.'),
              enabled: !_busy,
              onTap: _import,
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
              title: Text(
                'Delete all data',
                style: TextStyle(color: scheme.error),
              ),
              subtitle: const Text(
                'Readings, scores, recordings and settings on this phone.',
              ),
              enabled: !_busy,
              onTap: _deleteAll,
            ),
            const _Header('About'),
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: const Text('Licences'),
              subtitle: const Text(
                'Models, dictionary, voices, fonts and packages',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openLicences,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    ),
  );
}
