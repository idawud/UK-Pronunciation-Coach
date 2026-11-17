// Test double for VoiceService whose utterances last until the test finishes them
// (or until stop is called), so playback ordering and cancellation can be checked.
import 'dart:async';

import 'package:uk_pronunciation_coach/core/fakes/fakes.dart';

/// [FakeVoiceService] whose [speak] only completes when [finishNext] is called or
/// [stop] is called, like real speech.
class BlockingVoice extends FakeVoiceService {
  final List<Completer<void>> _pending = [];

  /// Utterances started and not yet finished, oldest first.
  int get pendingCount => _pending.length;

  @override
  Future<void> speak(String text, {double rate = 1.0}) {
    spoken.add((text, rate));
    final completer = Completer<void>();
    _pending.add(completer);
    return completer.future;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    for (final c in _pending) {
      if (!c.isCompleted) c.complete();
    }
    _pending.clear();
  }

  /// Finishes the oldest utterance still speaking.
  void finishNext() {
    final c = _pending.removeAt(0);
    if (!c.isCompleted) c.complete();
  }
}

/// [FakeVoiceService] whose [speak] always throws.
class ThrowingVoice extends FakeVoiceService {
  @override
  Future<void> speak(String text, {double rate = 1.0}) async {
    throw StateError('no voice');
  }
}
