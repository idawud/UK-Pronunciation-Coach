# lib/engine/scoring/config (owner: I2-eval in Wave 2; A3 created the initial config)

`scoring_config.dart`: `ScoringConfig` holds the GOP -> 0-100 calibration curve
(piecewise linear), the good / close / fix thresholds, missed / dropped / extra-word
rules, the fluency curve and weights, and `extraAccepted` (extra model symbols accepted
per British phoneme, on top of `../data/phoneme_map.dart`). All values are A3's initial
guesses. Tune by changing the defaults here or loading JSON with
`ScoringConfig.fromJson` and passing it to `GopPronunciationScorer(config: ...)`.
