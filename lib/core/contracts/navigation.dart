import '../models/attempt_result.dart';
import '../models/level_change.dart';

/// Route paths. U1 owns the router (lib/ui/shell/); every screen agent navigates with
/// these paths and the argument classes below, passed as go_router `extra`.
abstract final class AppRoutes {
  /// Home tab.
  static const home = '/';

  /// Practise tab: library, weak sounds, words due.
  static const practise = '/practise';

  /// Progress tab.
  static const progress = '/progress';

  /// Settings tab.
  static const settings = '/settings';

  /// Licences page (inside Settings).
  static const licences = '/settings/licences';

  /// First-run flow: welcome, microphone, voice check, placement.
  static const onboarding = '/onboarding';

  /// Read and record. `extra`: [ReadArgs].
  static const read = '/read';

  /// Results. `extra`: [ResultsArgs].
  static const results = '/results';

  /// Fix a word. `extra`: [FixArgs].
  static const fix = '/fix';
}

/// What the Read screen records.
enum ReadMode {
  /// A full passage. After scoring, the Read screen calls
  /// `PracticeEngine.recordAttempt` and replaces itself with Results.
  passage,

  /// The sentence containing [ReadArgs.wordIndex] (see `Passage.sentenceRange`).
  /// Pops with the scored [AttemptResult] (words keep their passage indices) and saves
  /// nothing; the caller decides.
  sentence,

  /// The single word [ReadArgs.wordIndex]. Pops with an [AttemptResult] holding that
  /// one word and saves nothing.
  word,

  /// A placement passage. Pops with the scored [AttemptResult] and saves nothing;
  /// onboarding passes all three to `PracticeEngine.completePlacement`.
  placement,
}

/// Arguments for [AppRoutes.read].
class ReadArgs {
  /// Creates read arguments. [wordIndex] is required for sentence and word modes.
  const ReadArgs({
    required this.passageId,
    this.mode = ReadMode.passage,
    this.wordIndex,
  }) : assert(
         mode == ReadMode.passage ||
             mode == ReadMode.placement ||
             wordIndex != null,
         'wordIndex is required for sentence and word modes',
       );

  /// `Passage.id` to read.
  final String passageId;

  /// What to record.
  final ReadMode mode;

  /// Target word for [ReadMode.sentence] and [ReadMode.word].
  final int? wordIndex;
}

/// Arguments for [AppRoutes.results].
class ResultsArgs {
  /// Creates results arguments.
  const ResultsArgs({required this.result, this.levelChange});

  /// The scored (and already saved) attempt.
  final AttemptResult result;

  /// Level change caused by this attempt, shown as a message.
  final LevelChange? levelChange;
}

/// Arguments for [AppRoutes.fix].
class FixArgs {
  /// Creates Fix a word arguments.
  const FixArgs({required this.result, this.wordIndexes});

  /// The attempt whose words are being fixed.
  final AttemptResult result;

  /// Word indexes to step through; null means `result.redWords`.
  final List<int>? wordIndexes;
}
