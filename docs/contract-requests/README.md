# Contract requests

`lib/core/contracts/`, `lib/core/models/`, the fakes and the shared suites in
`test/contracts/` are frozen after Wave 0. If you need a change, do not edit them:
write `docs/contract-requests/<agent-id>.md` with

1. what you want changed (exact signature or field),
2. why the current contract cannot do it (a workaround you tried, if any),
3. who else it affects (callers, the fake, the shared suite).

A human reviews the requests after Wave 1 and they are merged in one small PR before
Wave 2 (I1 applies them, updating fakes and callers).
