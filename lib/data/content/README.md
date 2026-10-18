# lib/data/content (owner: C1-content)

Implements `ContentRepository`: loads `assets/content/passages.v1.json`,
`lookup()` via the bundled Britfone table (unknown words `scorable: false`),
placement set (levels 1, 3, 5), minimal pairs. Never ships eSpeak.

Tests: `test/data/content/` running `runContentRepositoryContract` (`fullLibrary: true`).
