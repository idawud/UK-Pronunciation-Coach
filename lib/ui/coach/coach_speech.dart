import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/contracts/voice_service.dart';

/// Play and stop for the Coach tab. Only one utterance plays at a time, and [playing]
/// says which button is active so every toggle can show play or stop.
///
/// Generation-token pattern: every [play] and [stop] bumps [_gen]. A `speak` call
/// completes on finish or on stop, so when it returns it only clears [playing] if no
/// newer play or stop has happened since it started.
class CoachSpeech {
  /// Creates the helper over [_voice] (captured by the screen in `initState`).
  CoachSpeech(this._voice);

  final VoiceService _voice;
  int _gen = 0;
  bool _disposed = false;

  /// Key of the button whose utterance is speaking, or null.
  final ValueNotifier<String?> playing = ValueNotifier<String?>(null);

  /// Speaks [text] at [rate] for the button [key]. Starting a new utterance replaces
  /// the old one (the voice service stops anything already speaking).
  Future<void> play(String key, String text, {double rate = 1.0}) async {
    final gen = ++_gen;
    _set(key);
    try {
      await _voice.speak(text, rate: rate);
    } on Object {
      // A voice failure just ends the utterance; the button returns to play.
    }
    if (gen == _gen) _set(null);
  }

  /// Stops whatever is speaking and clears [playing].
  Future<void> stop() async {
    _gen++;
    _set(null);
    await _voice.stop();
  }

  /// Toggle used by the buttons: stops when [key] is the one playing, else plays.
  Future<void> toggle(String key, String text, {double rate = 1.0}) =>
      playing.value == key ? stop() : play(key, text, rate: rate);

  /// Stops speech and releases [playing]. Safe to call once, from the screen's dispose.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _gen++;
    unawaited(_voice.stop().catchError((_) {}));
    playing.dispose();
  }

  void _set(String? key) {
    if (_disposed) return;
    playing.value = key;
  }
}
