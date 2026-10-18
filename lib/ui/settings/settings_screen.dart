import 'package:flutter/material.dart';

/// Settings screen. Placeholder from W0-scaffold; U4-progress owns it and replaces the body,
/// keeping the class name and constructor (the router in lib/ui/shell/ builds it).
class SettingsScreen extends StatelessWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings (coming soon)')),
    );
  }
}
