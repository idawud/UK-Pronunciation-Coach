# lib/ui/shell (owner: U1-home)

App shell and router (`shell/app_router.dart`: every path in `AppRoutes`), theme
(`theme/app_theme.dart`, `theme/score_colors.dart` - keep `ScoreColors` and its
fields, other agents use them), Home, Practise tab and first-run onboarding.
Seeded placeholders keep fixed class names that the router builds; replace the bodies.

Tests: `test/ui/<folder>/`, goldens in `test/ui/goldens/` (see docs/testing.md).
