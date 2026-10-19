import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/fix/sound_chips.dart';
import 'package:uk_pronunciation_coach/ui/fix/sound_marks.dart';
import 'package:uk_pronunciation_coach/ui/theme/app_theme.dart';

PhonemeResult _p(String expected, {String? heard, int score = 90}) =>
    PhonemeResult(
      expected: expected,
      heard: heard,
      score: score,
      start: Duration.zero,
      end: const Duration(milliseconds: 80),
    );

void main() {
  test('soundIssue reads heard as A3 defines it', () {
    expect(soundIssue(_p('θ')), SoundIssue.ok);
    expect(soundIssue(_p('θ', heard: 'θ')), SoundIssue.ok);
    expect(soundIssue(_p('θ', heard: 't')), SoundIssue.substituted);
    expect(soundIssue(_p('d', heard: '')), SoundIssue.dropped);
    expect(soundIssue(_p('ɑː', heard: 'ɑːɹ')), SoundIssue.addedR);
    expect(soundIssue(_p('ɔː', heard: 'ɔːr')), SoundIssue.addedR);
    expect(soundIssue(_p('ɑː', heard: 'ɑːx')), SoundIssue.substituted);
  });

  test('expected and heard IPA', () {
    final thursday = riverPassage.words[1];
    expect(expectedIpa(thursday), '/θˈɜːzdeɪ/');
    expect(
      expectedIpa(
        const WordSpec(
          text: 'x',
          index: 0,
          phonemes: [
            PhonemeSpec(ipa: 'ɪ', stress: 2),
            PhonemeSpec(ipa: 'n'),
          ],
        ),
      ),
      '/ˌɪn/',
    );
    final ps = [_p('k'), _p('ɑː', heard: 'ɑːɹ'), _p('d', heard: ''), _p('z')];
    expect(expectedIpaOf(ps), '/kɑːdz/');
    expect(heardIpa(ps), '/kɑːɹz/');
    expect(hasSoundIssues(ps), isTrue);
    expect(hasSoundIssues([_p('k')]), isFalse);
  });

  test('worstSound prefers a wrong sound, then the lowest under 60', () {
    expect(worstSound([_p('a'), _p('b', heard: 'c')])!.expected, 'b');
    expect(
      worstSound([_p('a', score: 55), _p('b', score: 40), _p('c', score: 70)])!
          .expected,
      'b',
    );
    expect(worstSound([_p('a', score: 70)]), isNull);
  });

  testWidgets('chips mark substituted, dropped and added-r sounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SoundChips(
            phonemes: [
              _p('k'),
              _p('ɑː', heard: 'ɑːɹ', score: 40),
              _p('d', heard: '', score: 0),
              _p('θ', heard: 't', score: 20),
              _p('z', score: 65),
            ],
          ),
        ),
      ),
    );
    expect(find.text('added r'), findsOneWidget);
    expect(find.text('missing'), findsOneWidget);
    expect(find.text('heard /t/'), findsOneWidget);
    expect(find.text('65'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNWidgets(3));
    expect(find.bySemanticsLabel('Sound d was left out'), findsOneWidget);
  });
}
