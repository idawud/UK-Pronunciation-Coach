import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

import '../../contracts/pronunciation_scorer_contract.dart';
import '../../contracts/tips_contract.dart';

void main() {
  runPronunciationScorerContract(GopPronunciationScorer.new);
  runTipsContract(TableTips.new);
}
