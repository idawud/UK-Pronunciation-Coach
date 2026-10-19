# lib/ui/progress (owner: U4-progress)

`ProgressScreen` (built by the router): summary (level, streak, today vs goal), score
trend (fl_chart), level history, sounds weakest first, streak calendar. Data comes
from `progressDataProvider` (`progress_data.dart`), which reads `ProgressRepository`
and `PracticeEngine` and refreshes on every progress write. Colours come from
`Theme.of(context)` and `ScoreColors.of(context)` only.

Tests: `test/ui/progress/`; goldens in `test/ui/goldens/progress_golden_test.dart`.
