import 'package:flutter/material.dart';

/// Practise screen. Placeholder from W0-scaffold; U1-home owns it and replaces the body,
/// keeping the class name and constructor (the router in lib/ui/shell/ builds it).
class PractiseScreen extends StatelessWidget {
  /// Creates the screen.
  const PractiseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Practise')),
      body: const Center(child: Text('Practise (coming soon)')),
    );
  }
}
