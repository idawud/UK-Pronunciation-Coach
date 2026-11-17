import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/voice_service.dart';
import 'package:uk_pronunciation_coach/ui/coach/sounds/coach_exercises.dart';

void main() {
  test('exercise ids are unique', () {
    final ids = coachLibrary.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every exercise has a title, instructions and text to speak', () {
    for (final e in coachLibrary) {
      expect(e.title.trim(), isNotEmpty, reason: e.id);
      expect(e.instructions.trim(), isNotEmpty, reason: e.id);
      expect(e.speakText.trim(), isNotEmpty, reason: e.id);
    }
  });

  test('every category has exercises', () {
    for (final category in CoachCategory.values) {
      expect(
        coachLibrary.where((e) => e.category == category),
        isNotEmpty,
        reason: category.name,
      );
      expect(category.label.trim(), isNotEmpty);
    }
  });

  test('rates are within the voice range', () {
    for (final e in coachLibrary) {
      expect(e.rate, inInclusiveRange(0.1, 2.0), reason: e.id);
    }
  });

  test('speech rates default to normal and the slow rate is used', () {
    expect(
      const CoachExercise(
        id: 'x',
        title: 't',
        instructions: 'i',
        speakText: 's',
        category: CoachCategory.warmUp,
      ).rate,
      VoiceService.normalRate,
    );
    expect(coachLibrary.any((e) => e.rate == VoiceService.slowRate), isTrue);
  });

  test('the library has the expected mix and the named exercises', () {
    int count(CoachCategory c) =>
        coachLibrary.where((e) => e.category == c).length;
    expect(count(CoachCategory.warmUp), greaterThanOrEqualTo(4));
    expect(count(CoachCategory.tongueTwister), greaterThanOrEqualTo(5));
    expect(count(CoachCategory.paceBreathing), greaterThanOrEqualTo(3));

    final texts = coachLibrary.map((e) => e.speakText).join('\n');
    expect(texts, contains('Red lorry, yellow lorry'));
    expect(texts, contains('She sells seashells on the seashore'));
  });
}
