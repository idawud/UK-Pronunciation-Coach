import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/settings/reminder_scheduler.dart';
import 'ui/shell/app_router.dart';
import 'ui/theme/app_theme.dart';

/// Root widget. Theme comes from U1's `AppTheme`, routes from U1's `appRouterProvider`.
class CoachApp extends ConsumerWidget {
  /// Creates the app.
  const CoachApp({super.key});

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
