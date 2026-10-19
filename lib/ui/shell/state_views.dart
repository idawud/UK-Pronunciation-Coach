import 'package:flutter/material.dart';

/// Centred spinner with an optional [message]. Use for a screen's loading state.
class LoadingView extends StatelessWidget {
  /// Creates the view.
  const LoadingView({super.key, this.message});

  /// Text under the spinner.
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(message!, textAlign: TextAlign.center),
        ],
      ],
    ),
  );
}

/// Icon, title, explanation and an optional action. Use for empty, error and
/// permission-denied states so they look the same on every screen.
class MessageView extends StatelessWidget {
  /// Creates the view.
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Error state with a "Try again" button calling [onRetry].
  const MessageView.error({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'Your progress is safe. Please try again.',
    VoidCallback? onRetry,
  }) : icon = Icons.error_outline,
       actionLabel = onRetry == null ? null : 'Try again',
       onAction = onRetry;

  /// Leading icon.
  final IconData icon;

  /// Headline.
  final String title;

  /// Explanation.
  final String? message;

  /// Button label; no button when null.
  final String? actionLabel;

  /// Button action.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
