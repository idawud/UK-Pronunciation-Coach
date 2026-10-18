# lib/data (owner: C2-data, except lib/data/content/)

Implements `ProgressRepository` with drift (SQLite): attempts, word_results,
sound_stats (`SoundStat.update`), review_queue (`ReviewItem.afterScore`),
user_profile, level history, practice sessions; recordings deleted unless
`keepRecordings`; `exportJson` / `importJson` use `ProgressBackup`; migrations.

Tests: `test/data/` (in-memory database) running `runProgressRepositoryContract`.
