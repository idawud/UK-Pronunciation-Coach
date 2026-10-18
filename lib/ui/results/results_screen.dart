import 'package:flutter/material.dart';

import '../../core/contracts/navigation.dart';

/// Results screen. Placeholder from W0-scaffold; U3-results owns it and replaces the body,
/// keeping the class name and constructor (the router in lib/ui/shell/ builds it).
class ResultsScreen extends StatelessWidget {
  /// Creates the screen.
  const ResultsScreen({super.key, required this.args});

  /// The scored attempt and any level change.
  final ResultsArgs args;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: const Center(child: Text('Results (coming soon)')),
    );
  }
}
