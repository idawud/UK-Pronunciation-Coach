// Seeded by W0-scaffold for U2-read; replace with real widget tests for every state
// (loading, empty, error, permission denied) at phone and tablet sizes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/navigation.dart';
import 'package:uk_pronunciation_coach/ui/read/read_screen.dart';

void main() {
  testWidgets('ReadScreen placeholder renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReadScreen(args: const ReadArgs(passageId: 'sample-l3-river')),
      ),
    );
    expect(find.text('Read (coming soon)'), findsOneWidget);
  });
}
