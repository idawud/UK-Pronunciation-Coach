// Send feedback (R1-release): the email draft, the optional progress file and the
// build without a feedback address.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/ui/settings/feedback.dart';
import 'package:uk_pronunciation_coach/ui/settings/settings_screen.dart';

import '../progress/u4_harness.dart';

void main() {
  group('usableFeedbackEmail', () {
    test('accepts an address and trims it', () {
      expect(usableFeedbackEmail(' beta@coach.example '), 'beta@coach.example');
    });

    test('rejects unset, placeholder and malformed values', () {
      expect(usableFeedbackEmail(''), isNull);
      expect(usableFeedbackEmail(feedbackEmailPlaceholder), isNull);
      expect(usableFeedbackEmail('not an address'), isNull);
      expect(usableFeedbackEmail('a@b'), isNull);
    });

    test('the build default is the placeholder', () {
      // Tests run without --dart-define=FEEDBACK_EMAIL.
      expect(feedbackEmailDefine, feedbackEmailPlaceholder);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(feedbackEmailProvider), isNull);
    });
  });

  group('feedbackMailto', () {
    test('addresses the draft with a subject and an editable body', () {
      final uri = feedbackMailto(
        to: 'beta@coach.example',
        device: 'android 14',
      );
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'beta@coach.example');
      expect(uri.toString(), isNot(contains('+')));
      final query = Uri.splitQueryString(uri.query);
      expect(query['subject'], 'UK Pronunciation Coach feedback');
      expect(query['body'], contains('Phone: android 14'));
      expect(query['body'], isNot(contains('Progress file')));
    });

    test('reminds the user to attach the file they saved', () {
      final uri = feedbackMailto(
        to: 'beta@coach.example',
        attachedFileName: 'uk-coach-progress-2026-10-19.json',
        device: 'ios 17',
      );
      final body = Uri.splitQueryString(uri.query)['body']!;
      expect(body, contains('attach uk-coach-progress-2026-10-19.json'));
      expect(body, contains('no recordings'));
    });

    test('describes the device by default', () {
      expect(deviceSummary(), isNotEmpty);
      final body = Uri.splitQueryString(
        feedbackMailto(to: 'a@b.example').query,
      )['body']!;
      expect(body, contains('Phone: ${deviceSummary()}'));
    });
  });

  group('Settings > Send feedback', () {
    late FakeProgressRepository repo;
    late MemoryBackupFiles files;
    late List<Uri> launched;
    late bool launchResult;
    late bool launchThrows;

    setUp(() {
      repo = FakeProgressRepository(clock: testClock);
      files = MemoryBackupFiles();
      launched = [];
      launchResult = true;
      launchThrows = false;
    });

    Future<void> pump(
      WidgetTester tester, {
      String? to = 'beta@coach.example',
    }) async {
      tester.view.physicalSize = const Size(600, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testApp(
          const SettingsScreen(),
          overrides: [
            ...overridesFor(repo: repo, files: files),
            feedbackEmailProvider.overrideWithValue(to),
            emailLauncherProvider.overrideWithValue((uri) async {
              launched.add(uri);
              if (launchThrows) throw Exception('no activity');
              return launchResult;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> choose(WidgetTester tester, String action) async {
      await tester.tap(find.text('Send feedback'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nothing is sent until'), findsOneWidget);
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
    }

    testWidgets('cancel opens nothing', (tester) async {
      await pump(tester);
      await choose(tester, 'Cancel');
      expect(launched, isEmpty);
      expect(files.saved, isEmpty);
    });

    testWidgets('email only opens a draft without saving a file', (
      tester,
    ) async {
      await pump(tester);
      await choose(tester, 'Email only');
      expect(launched, hasLength(1));
      expect(launched.single.path, 'beta@coach.example');
      expect(files.saved, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('save file and email saves the progress file first', (
      tester,
    ) async {
      await pump(tester);
      await choose(tester, 'Save file and email');
      expect(files.saved.keys, ['uk-coach-progress-2026-10-19.json']);
      final body = Uri.splitQueryString(launched.single.query)['body']!;
      expect(body, contains('uk-coach-progress-2026-10-19.json'));
    });

    testWidgets('no draft when the user cancels saving the file', (
      tester,
    ) async {
      files.cancelSave = true;
      await pump(tester);
      await choose(tester, 'Save file and email');
      expect(launched, isEmpty);
    });

    testWidgets('shows the address when no mail app opens', (tester) async {
      launchResult = false;
      await pump(tester);
      await choose(tester, 'Email only');
      expect(
        find.text(
          'No email app was found. Please write to beta@coach.example.',
        ),
        findsOneWidget,
      );
      launchThrows = true;
      await choose(tester, 'Email only');
      expect(find.textContaining('No email app was found'), findsOneWidget);
    });

    testWidgets('disabled in a build without an address', (tester) async {
      await pump(tester, to: null);
      expect(find.text('Not available in this build.'), findsOneWidget);
      await tester.tap(find.text('Send feedback'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
