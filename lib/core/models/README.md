# lib/core/models (owner: W0-scaffold, frozen)

Immutable freezed + json_serializable models shared by every agent. Pure Dart (no
Flutter imports) so lib/engine/scoring and desktop tools can use them. Import
`models.dart`.

Frozen after Wave 0: do not edit. Propose changes in `docs/contract-requests/<agent-id>.md`.
After an approved change: `dart run build_runner build` and commit the generated files.

Shared rules that live here so C2 and C3 agree: `WordStatus.fromScore` (80 / 60),
`SoundStat.update` (EMA, alpha 0.3), `ReviewItem.afterScore` (1, 3, 7, 21 days),
`Passage.sentenceRange` / `slice` (sentence retries), `ProgressBackup` (export format).
