import 'package:flutter/material.dart';

/// Home screen. Placeholder from W0-scaffold; U1-home owns it and replaces the body,
/// keeping the class name and constructor (the router in lib/ui/shell/ builds it).
class HomeScreen extends StatelessWidget {
  /// Creates the screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('UK Pronunciation Coach')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Good morning', style: text.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Read a passage aloud and get British pronunciation feedback.',
                style: text.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const FilledButton(
                onPressed: null,
                child: Text("Start today's passage"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
