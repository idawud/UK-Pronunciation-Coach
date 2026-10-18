// Seeded by W0-scaffold for U4-progress; replace with real widget tests for every state
// (loading, empty, error, permission denied) at phone and tablet sizes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/ui/settings/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen placeholder renders', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SettingsScreen()));
    expect(find.text('Settings (coming soon)'), findsOneWidget);
  });
}
