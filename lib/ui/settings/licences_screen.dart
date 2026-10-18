import 'package:flutter/material.dart';

/// Licences screen. Placeholder from W0-scaffold; U4-progress owns it and replaces the body,
/// keeping the class name and constructor (the router in lib/ui/shell/ builds it).
class LicencesScreen extends StatelessWidget {
  /// Creates the screen.
  const LicencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Licences')),
      body: const Center(child: Text('Licences (coming soon)')),
    );
  }
}
