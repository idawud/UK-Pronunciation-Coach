/// Enums shared across the app. Pure Dart: safe to import from lib/engine/scoring.
library;

/// Which phoneme model tier is in use.
///
/// [light] is bundled with the app and gives word-level feedback only (the UI hides
/// per-sound detail). [full] is a one-time optional Wi-Fi download with per-sound detail.
enum ModelTier { light, full }

/// Result of the pre-scoring audio check on a recorded clip (A1).
enum AudioQuality {
  /// Loud and clean enough to score.
  ok,

  /// Peak level below -30 dBFS: ask the user to speak up or move closer.
  tooQuiet,

  /// Estimated SNR below 15 dB: ask the user to find a quieter spot.
  tooNoisy,
}

/// Microphone permission state as seen by [AudioRecorder] (A1).
enum MicPermission {
  /// Recording is allowed.
  granted,

  /// Not granted yet, or denied once; asking again may show the system prompt.
  denied,

  /// Denied permanently (or restricted); only the system settings can change it.
  permanentlyDenied,
}

/// Colour band of a scored word. Default thresholds: good >= 80, close 60-79, fix < 60.
enum WordStatus {
  /// Score >= 80 (green).
  good,

  /// Score 60-79 (amber, underlined).
  close,

  /// Score < 60 (red, underlined, with icon).
  fix,

  /// Not scored, e.g. not in the British dictionary (`WordSpec.scorable == false`). Grey.
  notScored,

  /// Expected but not said (alignment confidence below threshold). Score 0; treated as red.
  missed;

  /// Default good threshold. I2 may tune the real values in lib/engine/scoring/config/.
  static const int defaultGood = 80;

  /// Default close threshold.
  static const int defaultClose = 60;

  /// Maps a 0-100 [score] to [good], [close] or [fix] using the given thresholds.
  static WordStatus fromScore(
    int score, {
    int good = defaultGood,
    int close = defaultClose,
  }) {
    if (score >= good) return WordStatus.good;
    if (score >= close) return WordStatus.close;
    return WordStatus.fix;
  }

  /// True for statuses shown in red and counted by "Fix N red words" ([fix], [missed]).
  bool get isRed => this == WordStatus.fix || this == WordStatus.missed;
}

/// State of the optional full-model download (A2, shown by U2 and U4).
enum DownloadState {
  /// Nothing downloaded and no download running.
  idle,

  /// Requested, waiting for an unmetered (Wi-Fi) connection.
  waitingForWifi,

  /// Bytes are arriving.
  downloading,

  /// All bytes received; checking the SHA-256.
  verifying,

  /// Downloaded and verified; [ModelTier.full] can be loaded.
  completed,

  /// Failed (network, disk or checksum). A retry resumes where possible.
  failed,

  /// Cancelled by the user. A retry resumes where possible.
  cancelled,
}
