import 'package:flutter/material.dart';

import 'licence_data.dart';

/// Licences: every shipped model, dictionary, voice, content set, engine and font
/// (from [shippedLicences]), plus Flutter's page for the open-source packages.
class LicencesScreen extends StatelessWidget {
  /// Creates the screen.
  const LicencesScreen({super.key, this.entries = shippedLicences});

  /// Entries to list (defaults to everything shipped).
  final List<LicenceEntry> entries;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Licences')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Everything that scores and speaks runs on your phone. These are '
                  'the models, data and fonts the app uses, and their licences.',
                  style: t.bodyMedium,
                ),
              ),
              for (final kind in LicenceKind.values)
                if (entries.any((e) => e.kind == kind)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Semantics(
                      header: true,
                      child: Text(kind.title, style: t.titleSmall),
                    ),
                  ),
                  for (final e in entries.where((e) => e.kind == kind))
                    ListTile(
                      title: Text(e.name),
                      subtitle: Text([e.licence, e.source, ?e.note].join('\n')),
                      isThreeLine: true,
                    ),
                ],
              const Divider(height: 32),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Open-source packages'),
                subtitle: const Text(
                  'Licences of the code libraries in the app',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'UK Pronunciation Coach',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
