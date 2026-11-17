import 'package:flutter/foundation.dart';

import '../../core/contracts/contracts.dart';
import 'speech_segments.dart';

/// Which playback button is (or was last) running.
enum PlaybackKind {
  /// The whole sentence at normal speed.
  sentence,

  /// The passage with the non-good words slowed.
  stressed,

  /// Only the non-good words, slowly.
  wrongWords,
}

/// Plays [SpeechSegment]s one after another through a [VoiceService] and reports
/// which [PlaybackKind] is running.
///
/// Calling [play] with the kind that is already active stops playback. Calling it
/// with another kind switches to that kind. Every [play] and [stop] starts a new
/// generation; a sequence that finds its generation has moved on stops itself.
class SegmentPlayer extends ChangeNotifier {
  /// Creates a player that speaks through [_voice].
  SegmentPlayer(this._voice);

  final VoiceService _voice;
  PlaybackKind? _active;
  int _gen = 0;
  bool _disposed = false;

  /// The kind currently playing, or null when idle.
  PlaybackKind? get active => _active;

  /// Plays [segments] as [kind]. If [kind] is already active this stops instead.
  /// Completes when the sequence finishes, is stopped or is superseded.
  Future<void> play(PlaybackKind kind, List<SpeechSegment> segments) async {
    if (_disposed) return;
    if (_active == kind) {
      await stop();
      return;
    }
    final gen = ++_gen;
    _setActive(kind);
    try {
      for (final segment in segments) {
        if (gen != _gen) return;
        await _voice.speak(segment.text, rate: segment.rate);
      }
    } catch (_) {
      // Speech failed: fall back to idle rather than leaving a button stuck.
      if (gen == _gen) _setActive(null);
      return;
    }
    if (gen == _gen) _setActive(null);
  }

  /// Stops any playback in progress and returns to idle.
  Future<void> stop() async {
    _gen++;
    _setActive(null);
    await _voice.stop();
  }

  void _setActive(PlaybackKind? kind) {
    if (_disposed || _active == kind) return;
    _active = kind;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _gen++;
    _active = null;
    // Stop speech without waiting; the widget is going away.
    _voice.stop();
    super.dispose();
  }
}
