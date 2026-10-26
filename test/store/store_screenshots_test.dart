// Store screenshots (R1-release): the four main screens (Home, Read, Results,
// Progress) rendered with seeded fakes at the App Store and Google Play sizes, the
// same way the golden tests render them. Skipped unless asked for:
//
//   STORE_SCREENSHOTS=1 flutter test test/store/store_screenshots_test.dart
//
// writes store/screenshots/<device>/<n>-<screen>.png (docs/release.md, "Screenshots").
// Linux only, like the goldens, so text renders with the bundled fonts.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/navigation.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/home/home_screen.dart';
import 'package:uk_pronunciation_coach/ui/progress/progress_screen.dart';
import 'package:uk_pronunciation_coach/ui/read/read_screen.dart';
import 'package:uk_pronunciation_coach/ui/read/read_state.dart';
import 'package:uk_pronunciation_coach/ui/results/results_screen.dart';
import 'package:uk_pronunciation_coach/ui/theme/app_theme.dart';
import 'package:uk_pronunciation_coach/ui/theme/typography.dart';

import '../helpers/golden.dart';
import '../ui/progress/u4_harness.dart' as u4;
import '../ui/results/harness.dart' show Fakes;
import '../ui/shell/harness.dart';

/// A store screenshot size: [logical] points at [pixelRatio].
class StoreDevice {
  const StoreDevice(this.name, this.logical, this.pixelRatio);

  final String name;
  final Size logical;
  final double pixelRatio;

  Size get pixels => logical * pixelRatio;
}

/// Sizes the stores accept (portrait).
const storeDevices = [
  // Google Play phone: 1080 x 2160 (9:18; each side 320-3840 px, at most 2:1).
  StoreDevice('android-phone', Size(360, 720), 3),
  // Google Play 10-inch tablet: 1600 x 2560.
  StoreDevice('android-tablet', Size(800, 1280), 2),
  // App Store 6.9-inch iPhone: 1320 x 2868.
  StoreDevice('iphone-6.9', Size(440, 956), 3),
  // App Store 13-inch iPad: 2064 x 2752.
  StoreDevice('ipad-13', Size(1032, 1376), 2),
];

final _readState = ReadState(
  content: ReadContent(
    mode: ReadMode.passage,
    passage: riverPassage,
    target: riverPassage,
    passageNumber: 4,
    passageCount: 20,
  ),
  phase: ReadRecording(
    elapsed: const Duration(seconds: 12),
    levels: [for (var i = 0; i < 64; i++) 0.15 + 0.7 * ((i * 37) % 23) / 23],
  ),
);

/// The Read screen around a fixed recording state, as the goldens draw it.
class _ReadFrame extends StatelessWidget {
  const _ReadFrame();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(riverPassage.title)),
    body: LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 600;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxReadingWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 32 : 16,
                vertical: wide ? 24 : 12,
              ),
              child: ReadBody(state: _readState),
            ),
          ),
        );
      },
    ),
  );
}

final _results = ResultsArgs(
  result: cannedRiverAttempt,
  levelChange: LevelChange(
    from: 3,
    to: 4,
    reason: 'Three passages in a row at 85 or more: welcome to level 4.',
    at: DateTime(2026, 10, 15),
  ),
);

Widget _app(Widget screen, List<Object> overrides) => ProviderScope(
  overrides: overrides.cast(),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: withTestFonts(AppTheme.light()),
    home: screen,
  ),
);

bool get _enabled =>
    Platform.environment['STORE_SCREENSHOTS'] == '1' && Platform.isLinux;

Future<void> _loadAppFont() async {
  final file = File('assets/fonts/NotoSans-Regular.ttf');
  final loader = FontLoader(AppTypography.ipaFontFamily)
    ..addFont(Future.value(ByteData.sublistView(await file.readAsBytes())));
  await loader.load();
}

void main() {
  late Seeded home;
  late FakeProgressRepository progress;

  setUpAll(() async {
    if (!_enabled) return;
    await _loadAppFont();
    home = await seedHistory();
    progress = await u4.seededRepository();
  });

  final screens = <String, Widget Function()>{
    '1-home': () => _app(const HomeScreen(), home.overrides),
    '2-read': () => _app(const _ReadFrame(), Fakes().overrides),
    '3-results': () => _app(ResultsScreen(args: _results), Fakes().overrides),
    '4-progress': () =>
        _app(const ProgressScreen(), u4.overridesFor(repo: progress)),
  };

  for (final device in storeDevices) {
    for (final MapEntry(key: name, value: build) in screens.entries) {
      testWidgets('${device.name} $name', skip: !_enabled, (tester) async {
        tester.view.physicalSize = device.pixels;
        tester.view.devicePixelRatio = device.pixelRatio;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: build()));
        // Let futures resolve and entrance animations finish; the recording
        // waveform would keep pumpAndSettle busy, so pump a fixed time.
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final png = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: device.pixelRatio);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data!.buffer.asUint8List();
        });
        final out = File('store/screenshots/${device.name}/$name.png');
        await out.parent.create(recursive: true);
        await out.writeAsBytes(png!);
        final decoded = await tester.runAsync(
          () async => (await ui.instantiateImageCodec(png)).getNextFrame(),
        );
        expect(decoded!.image.width, device.pixels.width.round());
        expect(decoded.image.height, device.pixels.height.round());
      });
    }
  }

  test('store sizes follow the store rules', () {
    for (final d in storeDevices) {
      final w = d.pixels.width, h = d.pixels.height;
      expect(w, inInclusiveRange(320, 3840), reason: d.name);
      expect(h, inInclusiveRange(320, 3840), reason: d.name);
      expect(h / w, lessThanOrEqualTo(2.18), reason: d.name);
      expect(w, equals(w.roundToDouble()), reason: d.name);
    }
  });
}
