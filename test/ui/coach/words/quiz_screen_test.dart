import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/data/coach/coach_store.dart';
import 'package:uk_pronunciation_coach/ui/coach/words/lost_word.dart';
import 'package:uk_pronunciation_coach/ui/coach/words/lost_word_repository.dart';
import 'package:uk_pronunciation_coach/ui/coach/words/quiz_screen.dart';
import 'package:uk_pronunciation_coach/ui/shell/state_views.dart';

import '../../shell/harness.dart';

final _now = DateTime(2026, 10, 19, 9, 30);

LostWord _word(String word, {String? note}) =>
    LostWord(word: word, note: note, addedAt: _now, due: _now);

Future<({InMemoryCoachStore store, FakeVoiceService voice})> _pump(
  WidgetTester tester,
  List<LostWord> words,
) async {
  final store = InMemoryCoachStore();
  final repo = LostWordRepository(store: store, clock: () => _now);
  for (final w in words) {
    await repo.add(w.word, note: w.note);
  }
  final voice = FakeVoiceService();
  await tester.pumpWidget(
    harness(
      WordQuizScreen(words: words),
      overrides: [
        clockProvider.overrideWithValue(() => _now),
        coachStoreProvider.overrideWithValue(store),
        voiceServiceProvider.overrideWithValue(voice),
      ],
    ),
  );
  await tester.pumpAndSettle();
  return (store: store, voice: voice);
}

void main() {
  testWidgets('no due words shows the empty state', (tester) async {
    await _pump(tester, const []);
    expect(find.text('Nothing due right now'), findsOneWidget);
    expect(find.byType(MessageView), findsOneWidget);
    expect(find.text('Reveal'), findsNothing);
  });

  testWidgets('a card without a note says so, and the word stays hidden', (
    tester,
  ) async {
    await _pump(tester, [_word('quay')]);
    expect(
      find.text('No note saved. Picture the sentence you were in.'),
      findsOneWidget,
    );
    expect(find.text('quay'), findsNothing);
    expect(find.text('I knew it'), findsNothing);
  });

  testWidgets(
    'Reveal shows and speaks the word; Hear it again speaks it again',
    (tester) async {
      final s = await _pump(tester, [_word('quay', note: 'the dock')]);
      await tester.tap(find.text('Reveal'));
      await tester.pumpAndSettle();

      expect(find.text('quay'), findsOneWidget);
      expect(find.text('I knew it'), findsOneWidget);
      expect(find.text("Didn't"), findsOneWidget);
      expect(s.voice.spoken, [('quay', 1.0)]);

      await tester.tap(find.text('Hear it again'));
      await tester.pumpAndSettle();
      expect(s.voice.spoken, [('quay', 1.0), ('quay', 1.0)]);
    },
  );

  testWidgets('a miss is saved and the finished summary counts it', (
    tester,
  ) async {
    final s = await _pump(tester, [_word('quay', note: 'the dock')]);
    await tester.tap(find.text('Reveal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Didn't"));
    await tester.pumpAndSettle();

    expect(find.text('Review finished'), findsOneWidget);
    expect(find.text("Knew it: 0. Didn't: 1."), findsOneWidget);
    expect(find.text('Missed words are due again now.'), findsOneWidget);

    final stored = await LostWordRepository(
      store: s.store,
      clock: () => _now,
    ).list();
    expect(stored.single.box, 1);
    expect(stored.single.lapses, 1);
    expect(stored.single.due, _now);
    expect(s.voice.stopCount, greaterThan(0));
  });

  testWidgets('progress moves through two words and counts each answer', (
    tester,
  ) async {
    await _pump(tester, [_word('quay'), _word('scaffold')]);
    expect(find.text('Word 1 of 2'), findsOneWidget);

    await tester.tap(find.text('Reveal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I knew it'));
    await tester.pumpAndSettle();

    expect(find.text('Word 2 of 2'), findsOneWidget);

    await tester.tap(find.text('Reveal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Didn't"));
    await tester.pumpAndSettle();

    expect(find.text('Review finished'), findsOneWidget);
    expect(find.text("Knew it: 1. Didn't: 1."), findsOneWidget);
  });
}
