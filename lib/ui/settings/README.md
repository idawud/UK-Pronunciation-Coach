# lib/ui/settings (owner: U4-progress)

`SettingsScreen` and `LicencesScreen` (built by the router).

- `model_tier_section.dart`: tier choice and full-model download through
  `PhonemeRecognizer` (`settings_providers.dart` streams `downloadProgress`).
- `voice_section.dart`: British voice check through `VoiceService`.
- `reminder_scheduler.dart`: `ReminderScheduler` adapter, provider and start-up
  `reminderRestoreProvider`.
- `local_notifications_reminder_scheduler.dart`: the Android / iOS implementation
  on flutter_local_notifications (daily, inexact, device time zone).
- `backup_files.dart`: `BackupFiles` adapter + provider for export / import.
- `licence_data.dart`: shipped models, dictionary, voices, content, engines and fonts,
  seeded from docs/licences.md (keep in step).

Tests: `test/ui/settings/`; goldens in `test/ui/goldens/settings_golden_test.dart`.
