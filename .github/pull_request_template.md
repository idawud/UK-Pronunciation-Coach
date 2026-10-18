## What and why

<!-- Agent ID (e.g. A1-audio), what this adds, link to docs/handoff/<agent-id>.md -->

## Ownership

- [ ] I only touched folders my agent ID owns (see CLAUDE.md), or listed the exceptions below
- [ ] No edits to `lib/core/contracts/` or `lib/core/models/` (proposals go in `docs/contract-requests/<agent-id>.md`)

## Tests (docs/testing.md)

- [ ] Unit tests for all new logic, in `test/` mirroring my `lib/` path
- [ ] My implementation passes its shared suite from `test/contracts/`
- [ ] Widget tests for every screen state (loading, empty, error, permission denied), phone and tablet
- [ ] Golden tests updated on Linux (`flutter test --update-goldens --tags golden`), light + dark
- [ ] On-device tests in `integration_test/<agent-id>/` for native plug-ins (fixture audio, no mic, no network)
- [ ] pytest for any Python in `tools/`
- [ ] `scripts/check.sh` passes locally; coverage at or above my folder's gate
- [ ] No test skipped or deleted to get green (or the reason is in my handoff note)

## Rules

- [ ] No runtime network calls (A2's Wi-Fi model download excepted), no analytics / tracking / crash SDKs
- [ ] Only Apache-2.0 / MIT / BSD-style licences; every model, dictionary and voice is in `docs/licences.md`
- [ ] No large binaries committed (models go to GitHub Release assets)
- [ ] `docs/handoff/<agent-id>.md` written or updated
