// Test-local voice double for the Read screen preview tests (U2-read).
import 'dart:async';

import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';

/// [FakeVoiceService] whose `speak` stays pending until [finishSpeaking] is called
/// (or [stop] is called), so tests can observe the "speaking" state.
class ControllableVoice extends FakeVoiceService {
  Completer<void>? _pending;

  /// Whether a `speak` call is still pending.
  bool get isSpeaking => _pending != null;

  /// Completes the pending `speak`, as if the speech had finished.
  void finishSpeaking() {
    final p = _pending;
    _pending = null;
    if (p != null && !p.isCompleted) p.complete();
  }

  @override
  Future<void> speak(String text, {double rate = 1.0}) async {
    spoken.add((text, rate));
    final p = Completer<void>();
    _pending = p;
    await p.future;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    finishSpeaking();
  }
}
