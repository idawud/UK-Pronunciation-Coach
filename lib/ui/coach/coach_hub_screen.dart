import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/coach/coach_store.dart';
import '../theme/theme.dart';
import 'coach_sections.dart';

/// Coach tab hub: one card per entry in [coachSections], then a "Reset Coach data"
/// action. Each card pushes its section's sub-route, and the sub-screens get a back
/// button from the navigator.
class CoachScreen extends ConsumerWidget {
  /// Creates the hub.
  const CoachScreen({super.key});

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Coach data?'),
        content: const Text(
          'This clears everything the Coach sections have saved on this phone. '
          'Your progress and recordings are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(coachStoreProvider).clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Coach data cleared')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ReadingWidth(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Pick what you want to work on',
              style: text.titleMedium,
            ),
          ),
          for (final section in coachSections)
            ReadingWidth(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: Icon(section.icon),
                  title: Text(section.title),
                  subtitle: Text(section.subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(section.subPath),
                ),
              ),
            ),
          ReadingWidth(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset Coach data'),
                onPressed: () => _confirmReset(context, ref),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
