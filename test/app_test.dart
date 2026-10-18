import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/app.dart';
import 'package:uk_pronunciation_coach/main.dart' as app;

void main() {
  testWidgets('app starts on the placeholder home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CoachApp()));
    await tester.pumpAndSettle();
    expect(find.text('UK Pronunciation Coach'), findsOneWidget);
    expect(find.text("Start today's passage"), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('main() runs the app', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    expect(find.byType(CoachApp), findsOneWidget);
  });
}
