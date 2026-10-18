import 'package:flutter/material.dart';

import '../../core/contracts/navigation.dart';

/// Read screen. Placeholder from W0-scaffold; U2-read owns it and replaces the body,
/// keeping the class name and constructor (the router in lib/ui/shell/ builds it).
class ReadScreen extends StatelessWidget {
  /// Creates the screen.
  const ReadScreen({super.key, required this.args});

  /// What to read and how.
  final ReadArgs args;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Read')),
      body: const Center(child: Text('Read (coming soon)')),
    );
  }
}
