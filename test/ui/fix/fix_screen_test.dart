// Seeded by W0-scaffold for U3-results; replace with real widget tests for every state
// (loading, empty, error, permission denied) at phone and tablet sizes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/navigation.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/ui/fix/fix_screen.dart';

void main() {
  testWidgets('FixScreen placeholder renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FixScreen(args: FixArgs(result: cannedRiverAttempt)),
      ),
    );
    expect(find.text('Fix a word (coming soon)'), findsOneWidget);
  });
}
