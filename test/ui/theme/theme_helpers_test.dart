import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/ui/shell/state_views.dart';
import 'package:uk_pronunciation_coach/ui/theme/theme.dart';

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  group('ScoreCue', () {
    test('every status has an icon and label', () {
      for (final s in WordStatus.values) {
        expect(ScoreCue.label(s), isNotEmpty);
        expect(ScoreCue.icon(s), isA<IconData>());
      }
      expect(ScoreCue.underlined(WordStatus.good), isFalse);
      expect(ScoreCue.underlined(WordStatus.close), isTrue);
      expect(ScoreCue.underlined(WordStatus.missed), isTrue);
      expect(ScoreCue.showsIconInText(WordStatus.fix), isTrue);
      expect(ScoreCue.showsIconInText(WordStatus.close), isFalse);
    });

    testWidgets('word styles carry colour and underline cues', (tester) async {
      late Map<WordStatus, TextStyle> styles;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              styles = {
                for (final s in WordStatus.values)
                  s: ScoreCue.wordStyle(context, s),
              };
              return const SizedBox();
            },
          ),
        ),
      );
      const c = ScoreColors.light;
      expect(styles[WordStatus.good]!.color, c.good);
      expect(styles[WordStatus.good]!.decoration, isNull);
      expect(
        styles[WordStatus.close]!.decorationStyle,
        TextDecorationStyle.dashed,
      );
      expect(styles[WordStatus.fix]!.decoration, TextDecoration.underline);
      expect(
        styles[WordStatus.fix]!.decorationStyle,
        TextDecorationStyle.solid,
      );
      expect(styles[WordStatus.missed]!.color, c.fix);
      expect(styles[WordStatus.notScored]!.fontStyle, FontStyle.italic);
    });

    testWidgets('badge, icon and legend render in dark theme', (tester) async {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              ScoreBadge(score: 72, suffix: '%'),
              ScoreIcon(WordStatus.fix),
              ScoreLegend(),
            ],
          ),
          theme: AppTheme.dark(),
        ),
      );
      expect(find.text('72%'), findsOneWidget);
      expect(find.text('Good 80+'), findsOneWidget);
      expect(find.text('Close 60-79'), findsOneWidget);
      expect(find.text('Fix under 60'), findsOneWidget);
      expect(find.bySemanticsLabel('72%, Close'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.change_history).first);
      expect(icon.color, ScoreColors.dark.close);
    });

    test('forScore uses the default thresholds', () {
      const c = ScoreColors.light;
      expect(c.forScore(80), c.good);
      expect(c.forScore(79.6), c.good);
      expect(c.forScore(60), c.close);
      expect(c.forScore(10), c.fix);
    });
  });

  group('AppTypography', () {
    test('passage size maps the profile text scale to 18-22 sp', () {
      expect(AppTypography.passageSizeForScale(1), 20);
      expect(AppTypography.passageSizeForScale(0.5), 18);
      expect(AppTypography.passageSizeForScale(2), 22);
      expect(AppTypography.textScaleForSize(22), closeTo(1.1, 1e-9));
      expect(AppTypography.textScaleForSize(30), closeTo(1.1, 1e-9));
      expect(AppTypography.slashes(['θ', 'ɜː']), '/θ ɜː/');
    });

    testWidgets('passage and IPA styles', (tester) async {
      late TextStyle passage;
      late TextStyle ipa;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              passage = AppTypography.passage(context, size: 21);
              ipa = AppTypography.ipa(context, size: 16);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(passage.fontSize, 21);
      expect(ipa.fontFamily, AppTypography.ipaFontFamily);
      expect(ipa.fontSize, 16);
      expect(ipa.fontFamilyFallback, contains(AppTypography.ipaFontFamily));
    });

    test('passageTextSizeProvider follows the profile', () async {
      final progress = FakeProgressRepository();
      final container = ProviderContainer(
        overrides: [progressRepositoryProvider.overrideWithValue(progress)],
      );
      addTearDown(container.dispose);
      expect(container.read(passageTextSizeProvider), 20);
      await progress.saveProfile(const UserProfile(textScale: 1.1));
      container.invalidate(userProfileProvider);
      await container.read(userProfileProvider.future);
      expect(container.read(passageTextSizeProvider), closeTo(22, 1e-9));
    });

    test('themes use the IPA font as a fallback', () {
      for (final t in [AppTheme.light(), AppTheme.dark()]) {
        expect(
          t.textTheme.bodyLarge!.fontFamilyFallback,
          contains(AppTypography.ipaFontFamily),
        );
        expect(t.useMaterial3, isTrue);
      }
    });
  });

  group('responsive', () {
    test('window sizes and breakpoints', () {
      expect(Breakpoints.readingWidth, 680);
      expect(Breakpoints.twoPane, 720);
      expect(WindowSize.forWidth(390), WindowSize.compact);
      expect(WindowSize.forWidth(700), WindowSize.medium);
      expect(WindowSize.forWidth(1180), WindowSize.expanded);
      expect(TwoPane.isWide(820), isTrue);
      expect(TwoPane.isWide(390), isFalse);
    });

    Future<void> sized(WidgetTester tester, Size size, Widget child) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(child));
    }

    testWidgets('context queries on a phone', (tester) async {
      late BuildContext ctx;
      await sized(
        tester,
        const Size(390, 844),
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      );
      expect(ctx.windowSize, WindowSize.compact);
      expect(ctx.isTablet, isFalse);
      expect(ctx.useTwoPane, isFalse);
      expect(ctx.pagePadding.left, 16);
    });

    testWidgets('context queries on a tablet', (tester) async {
      late BuildContext ctx;
      await sized(
        tester,
        const Size(820, 1180),
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      );
      expect(ctx.windowSize, WindowSize.medium);
      expect(ctx.isTablet, isTrue);
      expect(ctx.useTwoPane, isTrue);
      expect(ctx.pagePadding.left, 24);
    });

    testWidgets('ReadingWidth caps the width', (tester) async {
      await sized(
        tester,
        const Size(1180, 820),
        const ReadingWidth(
          child: SizedBox(key: Key('c'), height: 10, width: 2000),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('c'))).width, 680);
    });

    testWidgets('TwoPane shows both panes when wide, narrow otherwise', (
      tester,
    ) async {
      const pane = TwoPane(
        primary: Text('primary'),
        secondary: Text('secondary'),
        narrow: Text('narrow'),
      );
      await sized(tester, const Size(820, 1180), pane);
      expect(find.text('primary'), findsOneWidget);
      expect(find.text('secondary'), findsOneWidget);
      await sized(tester, const Size(390, 844), pane);
      expect(find.text('narrow'), findsOneWidget);
      expect(find.text('secondary'), findsNothing);
      await sized(
        tester,
        const Size(390, 844),
        const TwoPane(primary: Text('primary'), secondary: Text('secondary')),
      );
      expect(find.text('primary'), findsOneWidget);
    });
  });

  group('state views', () {
    testWidgets('loading with a message', (tester) async {
      await tester.pumpWidget(_app(const LoadingView(message: 'Scoring...')));
      expect(find.text('Scoring...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('message view with action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          MessageView(
            icon: Icons.mic_off,
            title: 'Microphone is off',
            message: 'Turn it on.',
            actionLabel: 'Open settings',
            onAction: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('Open settings'));
      expect(taps, 1);
    });

    testWidgets('error view without retry has no button', (tester) async {
      await tester.pumpWidget(_app(const MessageView.error()));
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
