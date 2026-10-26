import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/ui/settings/bundled_licences.dart';
import 'package:uk_pronunciation_coach/ui/settings/licence_data.dart';
import 'package:uk_pronunciation_coach/ui/settings/licences_screen.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw FlutterError('missing $key');
    return ByteData.sublistView(Uint8List.fromList(text.codeUnits));
  }
}

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
      'wav2vec2-lv-60-espeak-cv-ft',
      'silero-vad',
      'Britfone',
      'VCTK',
      'Noto Sans',
      'SIL Open Font License',
      'ONNX Runtime',
      'desugar_jdk_libs',
    ]) {
      expect(shipped, contains(source));
      expect(pageText, contains(source), reason: source);
    }
  });

  group('bundled licence texts', () {
    setUp(() {
      LicenseRegistry.reset();
      resetBundledLicencesForTest();
    });
    tearDown(() {
      LicenseRegistry.reset();
      resetBundledLicencesForTest();
    });

    test('the asset files exist and are bundled', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final path in bundledLicenceAssets.values) {
        expect(File(path).existsSync(), isTrue, reason: path);
        final folder = path.substring(0, path.lastIndexOf('/') + 1);
        expect(
          pubspec.contains('- $path') || pubspec.contains('- $folder\n'),
          isTrue,
          reason: path,
        );
      }
    });

    test('registers each text once and skips missing ones', () async {
      final bundle = _Bundle({
        'assets/fonts/NotoSans-OFL.txt': 'SIL OPEN FONT LICENSE Version 1.1',
      });
      registerBundledLicences(bundle: bundle);
      registerBundledLicences(bundle: bundle);
      final entries = await LicenseRegistry.licenses.toList();
      expect(entries, hasLength(1));
      expect(entries.single.packages, ['Noto Sans (font)']);
      expect(
        entries.single.paragraphs.map((p) => p.text).join(),
        contains('SIL OPEN FONT LICENSE'),
      );
    });
  });
}
