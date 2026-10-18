# lib/core/fakes (owner: W0-scaffold)

A working fake for every contract, plus fixed sample data (`sample_data.dart`):
3 passages (levels 1, 3, 5) including "A walk by the river", a canned
`AttemptResult` with Thursday, castle and bath red, and `syntheticPosteriors()`
for building posteriors with a known right answer. Every fake passes its shared
contract suite (`test/contracts/fakes_contract_test.dart`).

Use fakes for anything you depend on; tweak their public fields to reach states
(e.g. `FakeAudioRecorder(permission: MicPermission.permanentlyDenied)`,
`FakePhonemeRecognizer(failDownload: true)`, `FakePronunciationScorer(wordScores: [40, 85])`).
Pure Dart.
