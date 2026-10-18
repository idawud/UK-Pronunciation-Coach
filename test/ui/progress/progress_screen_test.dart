// Seeded by W0-scaffold for U4-progress; replace with real widget tests for every state
// (loading, empty, error, permission denied) at phone and tablet sizes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/ui/progress/progress_screen.dart';

void main() {
  testWidgets('ProgressScreen placeholder renders', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ProgressScreen()));
    expect(find.text('Progress (coming soon)'), findsOneWidget);
  });
}
