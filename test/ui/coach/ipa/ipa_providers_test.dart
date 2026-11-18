import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/data/coach/coach_store.dart';
import 'package:uk_pronunciation_coach/ui/coach/ipa/ipa_providers.dart';

void main() {
  test('nothing is learned in an empty store', () async {
    final repo = IpaRepository(InMemoryCoachStore());
    expect(await repo.loadLearned(), isEmpty);
  });

  test('marking learned persists under the ipa key, sorted', () async {
    final store = InMemoryCoachStore();
    final repo = IpaRepository(store);
    await repo.setLearned('θ', true);
    await repo.setLearned('iː', true);
    expect(await repo.loadLearned(), {'θ', 'iː'});
    expect(await store.read(ipaStoreKey), {
      'learned': ['iː', 'θ'],
    });
  });

  test('unmarking removes the symbol and keeps the others', () async {
    final store = InMemoryCoachStore();
    final repo = IpaRepository(store);
    await repo.setLearned('p', true);
    await repo.setLearned('b', true);
    await repo.setLearned('p', false);
    expect(await repo.loadLearned(), {'b'});
    expect(await repo.loadLearned(), isNot(contains('p')));
  });

  test('a new repository over the same store sees the saved state', () async {
    final store = InMemoryCoachStore();
    await IpaRepository(store).setLearned('ʃ', true);
    expect(await IpaRepository(store).loadLearned(), {'ʃ'});
  });

  test('malformed data reads as nothing learned', () async {
    final store = InMemoryCoachStore();
    await store.write(ipaStoreKey, {'learned': 'not a list'});
    expect(await IpaRepository(store).loadLearned(), isEmpty);
    await store.write(ipaStoreKey, {
      'learned': ['ʃ', 3, null],
    });
    expect(await IpaRepository(store).loadLearned(), {'ʃ'});
  });
}
