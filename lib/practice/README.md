# lib/practice (owner: C3-practice)

Implements `PracticeEngine` on top of `ContentRepository` and `ProgressRepository`
(use the fakes): level rules, next-passage mix (70 / 20 / 10), spaced review via
`ReviewItem.afterScore`, placement, streaks and daily minutes (device time zone,
inject a `Clock`).

Tests: `test/practice/` (table-driven) running `runPracticeEngineContract`.
