import 'package:flutter/material.dart';

/// Progress screen. Placeholder from W0-scaffold; U4-progress owns it and replaces the body,
/// keeping the class name and constructor (the router in lib/ui/shell/ builds it).
class ProgressScreen extends StatelessWidget {
  /// Creates the screen.
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: const Center(child: Text('Progress (coming soon)')),
    );
  }
}
