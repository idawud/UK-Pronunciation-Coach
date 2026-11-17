import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/data/coach/coach_store.dart';
import 'package:uk_pronunciation_coach/ui/coach/words/lost_word_repository.dart';
import 'package:uk_pronunciation_coach/ui/coach/words/quiz_screen.dart';
import 'package:uk_pronunciation_coach/ui/coach/words/words_screen.dart';
import 'package:uk_pronunciation_coach/ui/shell/state_views.dart';

import '../../shell/harness.dart';

/// A store whose every read fails, for the error state.
class _FailingStore implements CoachStore {
  @override
  Future<Map<String, Object?>?> read(String key) =>
      Future<Map<String, Object?>?>.error(StateError('disk gone'));

  @override
  Future<void> write(String key, Map<String, Object?> value) async {}

  @override
  Future<void> clear() async {}
}

/// A store whose reads never finish, for the loading state.
class _PendingStore extends InMemoryCoachStore {
  final _never = Completer<Map<String, Object?>?>();

  @override
  Future<Map<String, Object?>?> read(String key) => _never.future;
}

final _now = DateTime(2026, 10, 19, 9, 30);

Future<void> _pump(
  WidgetTester tester, {
  required CoachStore store,
  FakeVoiceService? voice,
  DateTime? now,
}) async {
  final clockAt = now ?? _now;
  final overrides = <Override>[
    clockProvider.overrideWithValue(() => clockAt),
    coachStoreProvider.overrideWithValue(store),
    voiceServiceProvider.overrideWithValue(voice ?? FakeVoiceService()),
  ];
  await tester.pumpWidget(harness(const WordsScreen(), overrides: overrides));
  await tester.pumpAndSettle();
}

LostWordRepository _repo(CoachStore store, [DateTime? at]) =>
    LostWordRepository(store: store, clock: () => at ?? _now);

Future<void> _addViaForm(
  WidgetTester tester, {
  required String word,
  String? note,
}) async {
  await tester.enterText(find.byType(TextField).at(0), word);
  if (note != null) {
    await tester.enterText(find.byType(TextField).at(1), note);
  }
  await tester.tap(find.text('Add word'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty state explains the bank and disables Start review', (
    tester,
  ) async {
    await _pump(tester, store: InMemoryCoachStore());
    expect(find.text('No lost words yet'), findsOneWidget);
    expect(find.text('Nothing due today'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start review'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('add: a new word appears with its note', (tester) async {
    final store = InMemoryCoachStore();
    await _pump(tester, store: store);

    await _addViaForm(
      tester,
      word: '  scaffold ',
      note: 'the thing that holds up the building',
    );

    expect(find.text('scaffold'), findsOneWidget);
    // The note field's hint repeats this phrase, so scope the finder to the row.
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('the thing that holds up the building'),
      ),
      findsOneWidget,
    );
    expect(find.text('No lost words yet'), findsNothing);
    expect(find.text('1 word due now'), findsOneWidget);
    expect(await _repo(store).list(), hasLength(1));
  });

  testWidgets('add: a blank word is refused with a message', (tester) async {
    final store = InMemoryCoachStore();
    await _pump(tester, store: store);
    await tester.tap(find.text('Add word'));
    await tester.pump();
    expect(find.text('Type the word you lost first.'), findsOneWidget);
    expect(await _repo(store).list(), isEmpty);
  });

  testWidgets('add: a duplicate is refused, case-insensitively', (
    tester,
  ) async {
    final store = InMemoryCoachStore();
    await _repo(store).add('quay');
    await _pump(tester, store: store);

    await _addViaForm(tester, word: 'Quay');

    expect(find.text('"Quay" is already in your bank.'), findsOneWidget);
    expect(await _repo(store).list(), hasLength(1));
  });

  testWidgets('delete: the bin icon removes the word and saves the change', (
    tester,
  ) async {
    final store = InMemoryCoachStore();
    await _repo(store).add('scaffold');
    await _pump(tester, store: store);
    expect(find.text('scaffold'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete word'));
    await tester.pumpAndSettle();

    expect(find.text('scaffold'), findsNothing);
    expect(find.text('No lost words yet'), findsOneWidget);
    expect(await _repo(store).list(), isEmpty);
  });

  testWidgets('delete: swiping a row removes it', (tester) async {
    final store = InMemoryCoachStore();
    await _repo(store).add('scaffold');
    await _repo(store).add('quay');
    await _pump(tester, store: store);

    await tester.drag(find.text('quay'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('quay'), findsNothing);
    expect(find.text('scaffold'), findsOneWidget);
    expect((await _repo(store).list()).map((w) => w.word), ['scaffold']);
  });

  testWidgets('due banner counts only the words due now', (tester) async {
    final store = InMemoryCoachStore();
    final repo = _repo(store);
    await repo.add('scaffold');
    await repo.add('quay');
    await repo.review('quay', recalled: true); // due tomorrow
    await _pump(tester, store: store);

    expect(find.text('1 word due now'), findsOneWidget);
    expect(find.text('Due tomorrow'), findsOneWidget);
    expect(find.text('Due now'), findsOneWidget);
  });

  testWidgets('a word due in several days shows the count', (tester) async {
    final store = InMemoryCoachStore();
    final repo = _repo(store);
    await repo.add('quay');
    await repo.review('quay', recalled: true);
    await repo.review('quay', recalled: true); // box 3, due in 2 days
    await _pump(tester, store: store);
    expect(find.text('Due in 2 days'), findsOneWidget);
  });

  testWidgets('loading state shows a spinner while the bank loads', (
    tester,
  ) async {
    // A spinner animates forever, so pump a frame instead of settling.
    await tester.pumpWidget(
      harness(
        const WordsScreen(),
        overrides: [
          clockProvider.overrideWithValue(() => _now),
          coachStoreProvider.overrideWithValue(_PendingStore()),
          voiceServiceProvider.overrideWithValue(FakeVoiceService()),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // The add form stays on screen while the list loads.
    expect(find.text('Add word'), findsOneWidget);
  });

  testWidgets('error state offers a retry', (tester) async {
    await _pump(tester, store: _FailingStore());
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(MessageView), findsOneWidget);
  });

  testWidgets('quiz: Start review opens the quiz for the due words', (
    tester,
  ) async {
    final store = InMemoryCoachStore();
    final voice = FakeVoiceService();
    await _repo(store).add('scaffold', note: 'the frame');
    await _pump(tester, store: store, voice: voice);

    await tester.tap(find.text('Start review'));
    await tester.pumpAndSettle();

    // The words list stays mounted under the quiz, so scope finders to the quiz.
    final quiz = find.byType(WordQuizScreen);
    expect(quiz, findsOneWidget);
    expect(
      find.descendant(of: quiz, matching: find.text('Word 1 of 1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: quiz, matching: find.text('the frame')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: quiz, matching: find.text('scaffold')),
      findsNothing,
    );
    expect(voice.spoken, isEmpty);

    await tester.tap(find.text('Reveal'));
    await tester.pumpAndSettle();
    expect(voice.spoken, [('scaffold', 1.0)]);
    expect(
      find.descendant(of: quiz, matching: find.text('scaffold')),
      findsOneWidget,
    );

    await tester.tap(find.text('I knew it'));
    await tester.pumpAndSettle();
    expect(find.text('Review finished'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(WordsScreen), findsOneWidget);
    expect(find.text('Nothing due today'), findsOneWidget);
    final stored = (await _repo(store).list()).single;
    expect(stored.box, 2);
    expect(stored.due, _now.add(const Duration(days: 1)));
  });
}
