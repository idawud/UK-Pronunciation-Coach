import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/ui/coach/describe/describe_content.dart';

void main() {
  test('prompt ids and targets are unique', () {
    final ids = circumlocutionPrompts.map((p) => p.id).toList();
    final targets = circumlocutionPrompts.map((p) => p.target).toList();
    expect(ids.toSet().length, ids.length);
    expect(targets.toSet().length, targets.length);
  });

  test('there are about forty prompts', () {
    expect(circumlocutionPrompts.length, greaterThanOrEqualTo(40));
  });

  test('every prompt has a target, three hints and a category', () {
    for (final p in circumlocutionPrompts) {
      expect(p.target.trim(), isNotEmpty, reason: p.id);
      expect(p.hints, hasLength(3), reason: p.id);
      for (final hint in p.hints) {
        expect(hint.trim(), isNotEmpty, reason: p.id);
      }
    }
  });

  test('no hint contains the target word, ignoring case', () {
    for (final p in circumlocutionPrompts) {
      final target = p.target.toLowerCase();
      for (final hint in p.hints) {
        expect(
          hint.toLowerCase().contains(target),
          isFalse,
          reason: '${p.id}: hint "$hint" gives away "${p.target}"',
        );
      }
    }
  });

  test('every prompt category has prompts', () {
    for (final category in DescribeCategory.values) {
      expect(
        circumlocutionPrompts.where((p) => p.category == category),
        isNotEmpty,
        reason: category.name,
      );
      expect(category.label.trim(), isNotEmpty);
    }
  });

  test('phrase ids are unique and texts are non-empty', () {
    final ids = phraseChunks.map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final c in phraseChunks) {
      expect(c.text.trim(), isNotEmpty, reason: c.id);
    }
  });

  test('there are about sixty phrases', () {
    expect(phraseChunks.length, greaterThanOrEqualTo(60));
  });

  test('every phrase category has phrases', () {
    for (final category in PhraseCategory.values) {
      expect(
        phraseChunks.where((c) => c.category == category),
        isNotEmpty,
        reason: category.name,
      );
      expect(category.label.trim(), isNotEmpty);
    }
  });
}
