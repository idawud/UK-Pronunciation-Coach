import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';

void main() {
  test('errors describe themselves', () {
    expect(
      const MicPermissionException(MicPermission.denied).toString(),
      contains('denied'),
    );
    expect(
      const ModelNotAvailableException(ModelTier.full).toString(),
      contains('full'),
    );
    expect(const ModelDownloadException('x').toString(), contains('x'));
    expect(const PassageNotFoundException('p').toString(), contains('p'));
    expect(const AttemptNotFoundException('a').toString(), contains('a'));
  });

  test('systemClock is local now', () {
    final before = DateTime.now();
    final t = systemClock();
    expect(t.isUtc, isFalse);
    expect(t.isBefore(before), isFalse);
  });
}
