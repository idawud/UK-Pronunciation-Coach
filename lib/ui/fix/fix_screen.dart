import 'package:flutter/material.dart';

import '../../core/contracts/navigation.dart';

/// Fix a word screen. Placeholder from W0-scaffold; U3-results owns it and replaces the body,
/// keeping the class name and constructor (the router in lib/ui/shell/ builds it).
class FixScreen extends StatelessWidget {
  /// Creates the screen.
  const FixScreen({super.key, required this.args});

  /// The attempt and words to fix.
  final FixArgs args;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fix a word')),
      body: const Center(child: Text('Fix a word (coming soon)')),
    );
  }
}
