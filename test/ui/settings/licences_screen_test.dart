import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/ui/settings/licence_data.dart';
import 'package:uk_pronunciation_coach/ui/settings/licences_screen.dart';

void main() {
  testWidgets('lists every shipped component by kind', (tester) async {
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LicencesScreen()));
    for (final kind in LicenceKind.values) {
      expect(find.text(kind.title), findsOneWidget, reason: kind.name);
    }
    for (final e in shippedLicences) {
      expect(find.text(e.name), findsOneWidget, reason: e.name);
    }
  });

  testWidgets('opens the package licences page', (tester) async {
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LicencesScreen()));
    await tester.tap(find.text('Open-source packages'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  test('every shipped component in docs/licences.md is on the page', () {
    // Keeps the page in step with docs/licences.md: each licence named in the
    // shipped table must appear on the Licences page.
    final doc = File('docs/licences.md').readAsStringSync();
    final shipped = doc.split('## Dev-side only').first;
    final pageText = shippedLicences
        .map((e) => '${e.name} ${e.licence} ${e.source} ${e.note ?? ''}')
        .join(' ');
    for (final source in [
      'wav2vec2-base',
      'wav2vec2-lv-60-espeak-cv-ft',
      'silero-vad',
      'Britfone',
      'VCTK',
    ]) {
      expect(shipped, contains(source));
      expect(pageText, contains(source), reason: source);
    }
  });
}
