# integration_test/C2-data (owner: C2-data)

On-device SQLite tests for `lib/data/`: the shared `ProgressRepository` contract against
a real database file, persistence across reopen, and the 1,000-attempt load target.
No microphone or network. Run: `flutter test integration_test/C2-data -d <device>`.
