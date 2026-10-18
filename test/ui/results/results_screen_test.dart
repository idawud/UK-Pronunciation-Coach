// Seeded by W0-scaffold for U3-results; replace with real widget tests for every state
// (loading, empty, error, permission denied) at phone and tablet sizes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/navigation.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/ui/results/results_screen.dart';

void main() {
  testWidgets('ResultsScreen placeholder renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultsScreen(args: ResultsArgs(result: cannedRiverAttempt)),
      ),
    );
    expect(find.text('Results (coming soon)'), findsOneWidget);
  });
}
