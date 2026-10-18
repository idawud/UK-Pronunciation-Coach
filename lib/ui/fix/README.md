# lib/ui/fix (owner: U3-results)

Results (`ResultsScreen(args: ResultsArgs)`) and Fix a word (`FixScreen(args: FixArgs)`).
Colours from `ScoreColors.of(context)`; retries saved with
`ProgressRepository.updateWordResult`; hold-to-record through the `AudioRecorder`
contract; light tier (`AttemptResult.tier`) hides per-sound detail.

Tests: `test/ui/fix/`; goldens in `test/ui/goldens/`.
