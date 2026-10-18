import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';

/// Shared behaviour every [PhonemeRecognizer] must have.
///
/// - [create]: a fresh recognizer with no model loaded and the full tier not yet
///   downloaded.
/// - [clip]: a short speech clip to recognise (e.g. test/fixtures/audio/clean_read.wav).
/// - [checkDownload]: run the full-model download test. A real implementation must
///   inject a local/fake transport for it; the suite never touches the network.
void runPhonemeRecognizerContract(
  Future<PhonemeRecognizer> Function() create, {
  required AudioClip clip,
  bool checkDownload = true,
}) {
  group('PhonemeRecognizer contract', () {
    late PhonemeRecognizer r;

    setUp(() async => r = await create());
    tearDown(() async => r.dispose());

    test('starts unloaded; recognise before load throws StateError', () async {
      expect(r.loadedTier, isNull);
      await expectLater(r.recognise(clip), throwsStateError);
    });

    test('recommends a tier; light is always available', () async {
      expect(ModelTier.values, contains(await r.recommendedTier()));
      expect(await r.isTierAvailable(ModelTier.light), isTrue);
      expect(r.fullModelSizeBytes, greaterThan(0));
      expect(r.downloadProgress.isBroadcast, isTrue);
      expect(r.downloadStatus.isActive, isFalse);
    });

    test('loading an unavailable full tier throws', () async {
      if (await r.isTierAvailable(ModelTier.full)) return;
      await expectLater(
        r.load(ModelTier.full),
        throwsA(isA<ModelNotAvailableException>()),
      );
    });

    test('light tier gives well-formed log-posteriors', () async {
      await r.load(ModelTier.light);
      expect(r.loadedTier, ModelTier.light);
      await r.load(ModelTier.light); // no-op
      final p = await r.recognise(clip);
      expect(p.tier, ModelTier.light);
      expect(p.vocab, isNotEmpty);
      expect(p.vocab.toSet().length, p.vocab.length, reason: 'unique vocab');
      expect(p.blankIndex, inInclusiveRange(0, p.vocab.length - 1));
      expect(p.frameMs, greaterThan(0));
      expect(p.frames, isNotEmpty);
      final expected = clip.duration.inMilliseconds / p.frameMs;
      expect(
        (p.frames.length - expected).abs(),
        lessThanOrEqualTo(expected * 0.1 + 2),
        reason: 'about one frame per ${p.frameMs} ms of audio',
      );
      for (final f in p.frames) {
        expect(f.length, p.vocab.length);
        var sum = 0.0;
        for (final v in f) {
          expect(v.isFinite, isTrue);
          expect(v, lessThanOrEqualTo(1e-4));
          sum += math.exp(v);
        }
        expect(sum, closeTo(1.0, 0.01), reason: 'log-softmax frames');
      }
    });

    if (checkDownload) {
      test('full model downloads, loads and deletes', () async {
        final seen = <ModelDownloadProgress>[];
        final sub = r.downloadProgress.listen(seen.add);
        await r.downloadFullModel();
        await pumpEventQueue();
        await sub.cancel();
        expect(r.downloadStatus.state, DownloadState.completed);
        expect(seen.map((e) => e.state), contains(DownloadState.completed));
        var last = 0.0;
        for (final e in seen.where(
          (e) => e.state == DownloadState.downloading,
        )) {
          expect(e.fraction, greaterThanOrEqualTo(last));
          last = e.fraction;
        }
        expect(await r.isTierAvailable(ModelTier.full), isTrue);
        await r.downloadFullModel(); // already done: returns at once
        await r.load(ModelTier.full);
        expect(r.loadedTier, ModelTier.full);
        expect((await r.recognise(clip)).tier, ModelTier.full);
        await r.deleteFullModel();
        expect(await r.isTierAvailable(ModelTier.full), isFalse);
        expect(r.loadedTier, isNull);
        expect(r.downloadStatus.state, DownloadState.idle);
      });
    }
  });
}
