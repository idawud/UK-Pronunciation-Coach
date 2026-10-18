import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contracts/navigation.dart';
import '../fix/fix_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../practise/practise_screen.dart';
import '../progress/progress_screen.dart';
import '../read/read_screen.dart';
import '../results/results_screen.dart';
import '../settings/licences_screen.dart';
import '../settings/settings_screen.dart';

/// The app router (seeded by W0 with every route in `AppRoutes`; U1 owns it).
/// Tabs use a stateful shell; Read, Results, Fix and Onboarding are full-screen.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
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
                builder: (context, state) => const PractiseScreen(),
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

/// Bottom navigation shell: Home, Practise, Progress, Settings.
class AppShell extends StatelessWidget {
  /// Creates the shell around [shell].
  const AppShell({super.key, required this.shell});

  /// The tab navigator.
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Practise',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
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
