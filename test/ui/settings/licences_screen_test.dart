// Seeded by W0-scaffold for U4-progress; replace with real tests.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/ui/settings/licences_screen.dart';

void main() {
  testWidgets('LicencesScreen placeholder renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LicencesScreen()));
    expect(find.text('Licences (coming soon)'), findsOneWidget);
  });
}
