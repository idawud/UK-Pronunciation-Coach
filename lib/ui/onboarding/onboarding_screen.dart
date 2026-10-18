import 'package:flutter/material.dart';

/// Welcome screen. Placeholder from W0-scaffold; U1-home owns it and replaces the body,
/// keeping the class name and constructor (the router in lib/ui/shell/ builds it).
class OnboardingScreen extends StatelessWidget {
  /// Creates the screen.
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: const Center(child: Text('Welcome (coming soon)')),
    );
  }
}
