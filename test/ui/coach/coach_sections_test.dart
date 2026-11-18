import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/ui/coach/coach_routes.dart';
import 'package:uk_pronunciation_coach/ui/coach/coach_sections.dart';

void main() {
  test('there are six sections with unique ids', () {
    expect(coachSections.map((s) => s.id).toList(), [
      'sounds',
      'confusions',
      'words',
      'record',
      'describe',
      'ipa',
    ]);
  });

  test('each subPath is coachPath plus the relative id', () {
    for (final s in coachSections) {
      expect(s.subPath, '$coachPath/${s.id}', reason: s.id);
    }
  });

  test('the stated sub-paths match the registry', () {
    expect(coachSections.map((s) => s.subPath).toList(), [
      '/coach/sounds',
      '/coach/confusions',
      '/coach/words',
      '/coach/record',
      '/coach/describe',
      '/coach/ipa',
    ]);
  });
}
