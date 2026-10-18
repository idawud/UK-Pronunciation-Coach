// Seeded by W0-scaffold for U1-home; replace with real widget tests for every state
// (loading, empty, error, permission denied) at phone and tablet sizes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/ui/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('OnboardingScreen placeholder renders', (tester) async {
    await tester.pumpWidget(MaterialApp(home: OnboardingScreen()));
    expect(find.text('Welcome (coming soon)'), findsOneWidget);
  });
}
