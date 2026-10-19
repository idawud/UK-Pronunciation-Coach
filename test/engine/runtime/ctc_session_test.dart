import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/engine/runtime/ctc_session.dart';

import 'helpers/fakes.dart';
import 'helpers/host_ort.dart';

void main() {
  final lib = hostOrtLibraryPath();

  group(
    'OrtCtcModelSession',
    skip: lib == null ? 'no host ONNX Runtime' : false,
    () {
      test('runs a model without attention_mask', () async {
        final s = OrtCtcModelSession.open(
          tinyModel,
          libraryPath: lib,
          threads: 1,
        );
        final out = s.run(Float32List(16000));
        expect(out.frames, 49, reason: 'floor((16000 - 400) / 320) + 1');
        expect(out.vocabSize, 8);
        expect(out.data, hasLength(49 * 8));
        await s.close();
        await s.close(); // idempotent
        expect(() => s.run(Float32List(400)), throwsStateError);
      });

      test('feeds attention_mask when the model has one', () async {
        final s = OrtCtcModelSession.open(tinyMaskModel, libraryPath: lib);
        final out = s.run(Float32List(800));
        expect(out.frames, 2);
        await s.close();
      });

      test('reports ONNX Runtime errors', () {
        expect(
          () => OrtCtcModelSession.open(
            '$fixtures/missing.onnx',
            libraryPath: lib,
          ),
          throwsA(isA<OnnxRuntimeException>()),
        );
        final s = OrtCtcModelSession.open(tinyModel, libraryPath: lib);
        expect(
          () => s.run(Float32List(100)),
          throwsA(
            isA<OnnxRuntimeException>().having(
              (e) => e.toString(),
              'text',
              contains('OnnxRuntimeException'),
            ),
          ),
          reason: 'input shorter than the conv kernel',
        );
      });
    },
  );

  test('defaultInferenceThreads is between 1 and 4', () {
    expect(defaultInferenceThreads(), inInclusiveRange(1, 4));
  });

  test('openOnnxRuntimeLibrary fails cleanly for a missing path', () {
    expect(
      () => openOnnxRuntimeLibrary('/nonexistent/libonnxruntime.so'),
      throwsArgumentError,
    );
  });
}
