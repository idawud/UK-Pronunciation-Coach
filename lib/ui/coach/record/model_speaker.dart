import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/contracts/voice_service.dart';

/// Play and stop for the model line in the Record & compare section.
///
/// Uses the same generation-token pattern as `sounds/coach_speech.dart`: every [play]
/// and [stop] bumps [_gen], and a `speak` call completes on finish or on stop, so when
/// it returns it only clears [playing] if nothing newer has happened. The helper is
/// copied rather than imported so that the sections stay independent.
class ModelSpeaker {
  /// Creates the speaker over [_voice].
  ModelSpeaker(this._voice);

  final VoiceService _voice;
  int _gen = 0;
  bool _disposed = false;

  /// Key of the control whose utterance is speaking, or null.
  final ValueNotifier<String?> playing = ValueNotifier<String?>(null);

  /// Speaks [text] at [rate] for the control [key]. Completes when the speech finishes
  /// or is stopped. A voice failure ends the utterance quietly.
  Future<void> play(String key, String text, {double rate = 1.0}) async {
    if (_disposed) return;
    final gen = ++_gen;
    _set(key);
    try {
      await _voice.speak(text, rate: rate);
    } on Object {
      // The utterance ends; the control returns to idle below.
    }
    if (gen == _gen) _set(null);
  }

  /// Stops speech and clears [playing]. Safe at any time.
  Future<void> stop() async {
    _gen++;
    _set(null);
    try {
      await _voice.stop();
    } on Object {
      // Nothing to undo if the voice already stopped.
    }
  }

  /// Stops when [key] is the one speaking, otherwise plays.
  Future<void> toggle(String key, String text, {double rate = 1.0}) =>
      playing.value == key ? stop() : play(key, text, rate: rate);

  /// Stops speech and releases [playing]. Safe to call more than once.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _gen++;
    unawaited(_voice.stop().catchError((Object _) {}));
    playing.dispose();
  }

  void _set(String? key) {
    if (_disposed) return;
    playing.value = key;
  }
}
