# lib/engine/scoring (owner: A3-scoring)

Implements `PronunciationScorer` and `Tips` in pure Dart (no Flutter imports;
`test/engine/scoring/pure_dart_test.dart` enforces it): phoneme mapping table,
CTC Viterbi forced alignment, GOP scores, word / accuracy / fluency, tips table (25+).

Calibration lives in `config/` (owned by I2-eval in Wave 2).
Tests: `test/engine/scoring/`; run `runPronunciationScorerContract` with
`checkSemantics: true`. Synthetic posteriors: `syntheticPosteriors()` in
lib/core/fakes/sample_data.dart.
