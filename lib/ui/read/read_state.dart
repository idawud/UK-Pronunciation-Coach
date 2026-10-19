import 'package:flutter/foundation.dart';

import '../../core/contracts/navigation.dart';
import '../../core/models/models.dart';

/// What the Read screen shows: the passage (or sentence / word) to read, plus the
/// current [phase]. Built and updated by `ScoringController`.
@immutable
class ReadState {
  /// Creates a state.
  const ReadState({
    required this.phase,
    this.content,
    this.textScale = 1.0,
    this.downloadNotice,
  });

  /// The text to read; null while loading or when the passage could not be loaded.
  final ReadContent? content;

  /// Where the screen is in the read -> record -> score flow.
  final ReadPhase phase;

  /// Passage text size multiplier (`UserProfile.textScale`; 1.0 = 20 sp).
  final double textScale;

  /// Set while the wanted model tier (full) is still downloading, so this reading is
  /// scored with the light tier (or, when no tier is on the phone, waits for it).
  final ModelDownloadProgress? downloadNotice;

  /// Copy with some fields replaced. Pass `clearDownloadNotice` to remove the notice.
  ReadState copyWith({
    ReadContent? content,
    ReadPhase? phase,
    double? textScale,
    ModelDownloadProgress? downloadNotice,
    bool clearDownloadNotice = false,
  }) => ReadState(
    content: content ?? this.content,
    phase: phase ?? this.phase,
    textScale: textScale ?? this.textScale,
    downloadNotice: clearDownloadNotice
        ? null
        : downloadNotice ?? this.downloadNotice,
  );
}

/// The text being read and where it sits in its passage.
@immutable
class ReadContent {
  /// Creates the content.
  const ReadContent({
    required this.mode,
    required this.passage,
    required this.target,
    this.firstWordIndex = 0,
    this.passageNumber,
    this.passageCount,
  });

  /// What is being recorded.
  final ReadMode mode;

  /// The whole passage.
  final Passage passage;

  /// What the user reads: the whole passage, or a slice (sentence or word) re-indexed
  /// from 0.
  final Passage target;

  /// Passage index of `target.words[0]` (0 for passage and placement modes).
  final int firstWordIndex;

  /// 1-based position of the passage in its level, when known.
  final int? passageNumber;

  /// Number of passages in the level, when known.
  final int? passageCount;
}

/// The screen's phase. Exhaustive: the screen switches over every subtype.
@immutable
sealed class ReadPhase {
  const ReadPhase();
}

/// Loading the passage and profile.
class ReadLoading extends ReadPhase {
  /// Creates the phase.
  const ReadLoading();
}

/// The passage could not be loaded (unknown id or storage error).
class ReadLoadFailed extends ReadPhase {
  /// Creates the phase.
  const ReadLoadFailed(this.message);

  /// Short explanation for the user.
  final String message;
}

/// Ready to record.
class ReadIdle extends ReadPhase {
  /// Creates the phase.
  const ReadIdle();
}

/// Recording.
class ReadRecording extends ReadPhase {
  /// Creates the phase.
  const ReadRecording({required this.elapsed, required this.levels});

  /// Time since recording started.
  final Duration elapsed;

  /// Recent input levels (0-1), oldest first, for the waveform.
  final List<double> levels;
}

/// Steps of scoring, in order.
enum ScoringStage {
  /// Finding speech in the clip (voice-activity detection).
  checkingAudio,

  /// Loading the phoneme model.
  preparingModel,

  /// No model tier on the phone yet; waiting for the full-model download.
  waitingForDownload,

  /// Running the phoneme model (the slow part).
  recognising,

  /// Aligning and scoring.
  scoring,

  /// Saving the attempt (passage mode).
  saving,
}

/// Scoring a finished recording. The user can cancel.
class ReadScoring extends ReadPhase {
  /// Creates the phase.
  const ReadScoring({required this.stage, required this.progress});

  /// Current step.
  final ScoringStage stage;

  /// Estimated overall progress 0.0-1.0 (never reaches 1.0 before the result).
  final double progress;
}

/// Microphone permission is missing.
class ReadPermissionDenied extends ReadPhase {
  /// Creates the phase.
  const ReadPermissionDenied({required this.permanently});

  /// True when only the system settings can grant it.
  final bool permanently;
}

/// Why a recording cannot be scored and should be retried.
enum RetryReason {
  /// Peak level too low.
  tooQuiet,

  /// Too much background noise.
  tooNoisy,

  /// The voice-activity detector found no speech.
  noSpeech,
}

/// The recording was not good enough to score; offer a retry.
class ReadRetryNeeded extends ReadPhase {
  /// Creates the phase.
  const ReadRetryNeeded(this.reason);

  /// What was wrong.
  final RetryReason reason;
}

/// Recording or scoring failed unexpectedly.
class ReadFailed extends ReadPhase {
  /// Creates the phase.
  const ReadFailed(this.message);

  /// Short explanation for the user.
  final String message;
}

/// Scored. The screen navigates away: Results for passage mode, otherwise it pops
/// with [result].
class ReadDone extends ReadPhase {
  /// Creates the phase.
  const ReadDone({required this.result, this.levelChange});

  /// The scored attempt (saved in passage mode; unsaved otherwise).
  final AttemptResult result;

  /// Level change caused by a passage attempt, if any.
  final LevelChange? levelChange;
}
