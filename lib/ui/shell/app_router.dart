import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contracts/navigation.dart';
import '../../core/contracts/progress_repository.dart';
import '../../core/providers.dart';
import '../fix/fix_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../practise/practise_screen.dart';
import '../progress/progress_screen.dart';
import '../read/read_screen.dart';
import '../results/results_screen.dart';
import '../settings/licences_screen.dart';
import '../settings/settings_screen.dart';
import '../theme/responsive.dart';

/// Tab paths that need the first-run flow finished first.
const _gatedPaths = {
  AppRoutes.home,
  AppRoutes.practise,
  AppRoutes.progress,
  AppRoutes.settings,
  AppRoutes.licences,
};

/// Sends the user to onboarding until `UserProfile.onboardingDone` is true. Only the
/// tab routes are gated: Read (used by placement), Results, Fix and Onboarding are not.
/// If the profile cannot be read, the app opens normally rather than locking the user out.
@visibleForTesting
Future<String?> onboardingRedirect(
  ProgressRepository progress,
  String location,
) async {
  if (!_gatedPaths.contains(location)) return null;
  try {
    final profile = await progress.profile();
    return profile.onboardingDone ? null : AppRoutes.onboarding;
  } on Object {
    return null;
  }
}

/// The app router (seeded by W0 with every route in `AppRoutes`; U1 owns it).
/// Tabs use a stateful shell; Read, Results, Fix and Onboarding are full-screen.
/// Until onboarding is done the tab routes redirect to [AppRoutes.onboarding].
/// The Practise tab takes an optional `?tab=library|sounds|review` query.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) => onboardingRedirect(
      ref.read(progressRepositoryProvider),
      state.matchedLocation,
    ),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.practise,
                builder: (context, state) => PractiseScreen(
                  initialTab: PractiseTab.fromQuery(
                    state.uri.queryParameters['tab'],
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.progress,
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'licences',
                    builder: (context, state) => const LicencesScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.read,
        builder: (context, state) => switch (state.extra) {
          final ReadArgs args => ReadScreen(args: args),
          _ => const MissingArgumentsScreen(),
        },
      ),
      GoRoute(
        path: AppRoutes.results,
        builder: (context, state) => switch (state.extra) {
          final ResultsArgs args => ResultsScreen(args: args),
          _ => const MissingArgumentsScreen(),
        },
      ),
      GoRoute(
        path: AppRoutes.fix,
        builder: (context, state) => switch (state.extra) {
          final FixArgs args => FixScreen(args: args),
          _ => const MissingArgumentsScreen(),
        },
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Navigation shell: Home, Practise, Progress, Settings. A bottom navigation bar on
/// phones and portrait tablets; a navigation rail from [Breakpoints.rail] wide.
class AppShell extends StatelessWidget {
  /// Creates the shell around [shell].
  const AppShell({super.key, required this.shell});

  /// The tab navigator.
  final StatefulNavigationShell shell;

  static const _tabs = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.menu_book_outlined, Icons.menu_book, 'Practise'),
    (Icons.insights_outlined, Icons.insights, 'Progress'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  void _select(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    if (context.windowSize == WindowSize.expanded) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final (icon, selected, label) in _tabs)
                    NavigationRailDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selected),
                      label: Text(label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: shell),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _select,
        destinations: [
          for (final (icon, selected, label) in _tabs)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selected),
              label: label,
            ),
        ],
      ),
    );
  }
}

/// Shown when a route that needs `extra` arguments is opened without them
/// (e.g. after the app is restored from a deep link).
class MissingArgumentsScreen extends StatelessWidget {
  /// Creates the screen.
  const MissingArgumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: TextButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Something went wrong. Back to Home'),
        ),
      ),
    );
  }
}
