# lib/engine/scoring/config (owner: I2-eval in Wave 2; A3 created the initial config)

`scoring_config.dart`: `ScoringConfig` holds:

- the GOP -> 0-100 calibration curve (piecewise linear);
- the good / close / fix thresholds;
- the missed / dropped / extra-word rules;
- the fluency curve and weights;
- `extraAccepted`: extra model symbols accepted per British phoneme, on top of
  `../data/phoneme_map.dart`.

The defaults are I2-eval's engine-spike calibration for the full-tier model, measured on
native Southern British VCTK speakers: 3.6% false red words, with 89% of controlled errors
still red. See `docs/eval-report.md`. A3's original curve is kept as
`ScoringConfig.a3Calibration`.

To re-tune, use `tools/eval/` (`run_harness.sh`, `calibrate.py`). Then change the
defaults here, or load JSON with `ScoringConfig.fromJson` and pass it to
`GopPronunciationScorer(config: ...)`. Note that a JSON `extraAccepted` replaces the
default map; it is not merged into it. Re-tune once A4's light model exists.
