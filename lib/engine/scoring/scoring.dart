/// A3-scoring: pure-Dart pronunciation scoring (alignment, GOP, fluency, tips).
library;

export 'config/scoring_config.dart';
export 'ctc_aligner.dart' show CtcAlignment, alignCtc;
export 'fluency.dart';
export 'gop_pronunciation_scorer.dart';
export 'phoneme_mapper.dart';
export 'table_tips.dart';
