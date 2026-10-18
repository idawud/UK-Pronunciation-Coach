# lib/ui/read (owner: U2-read)

Read and record screen (`ReadScreen(args: ReadArgs)`, built by the router) and
its `ScoringController`: recorder -> recognizer -> scorer, then
`PracticeEngine.recordAttempt` and `AppRoutes.results` (passage mode) or pop with
the result (sentence / word / placement modes; see `ReadMode`).

Tests: `test/ui/read/` for every state at phone and tablet sizes; goldens in
`test/ui/goldens/`.
