import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'ui/settings/reminder_scheduler.dart';
import 'ui/shell/app_router.dart';
import 'ui/shell/state_views.dart';
import 'ui/theme/app_theme.dart';

/// Root widget. Theme comes from U1's `AppTheme`, routes from U1's `appRouterProvider`.
///
/// Waits for [appStartupProvider] (database and model runtime) before building the
/// router, showing a loading screen meanwhile and an error screen with "Try again"
/// if start-up fails.
class CoachApp extends ConsumerWidget {
  /// Creates the app.
  const CoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (useFakes) return const _ReadyApp(); // nothing to open
    final startup = ref.watch(appStartupProvider);
    if (!startup.hasValue) {
      return MaterialApp(
        title: 'UK Pronunciation Coach',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: Scaffold(
          body: startup.hasError && !startup.isLoading
              ? MessageView.error(
                  title: "The app couldn't start",
                  message:
                      'Your progress is safe. Restart the app or try again.',
                  onRetry: () => _retry(ref),
                )
              : const LoadingView(),
        ),
      );
    }
    return const _ReadyApp();
  }

  /// Re-runs the start-up steps that failed (a step that worked is kept).
  static void _retry(WidgetRef ref) {
    for (final step in [progressStoreProvider, recognizerStoreProvider]) {
      if (ref.read(step).hasError) ref.invalidate(step);
    }
    ref.invalidate(appStartupProvider);
  }
}

class _ReadyApp extends ConsumerWidget {
  const _ReadyApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-schedule the saved daily reminder once per launch (no rebuild on finish).
    ref.listen(reminderRestoreProvider, (_, _) {});
    return MaterialApp.router(
      title: 'UK Pronunciation Coach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
