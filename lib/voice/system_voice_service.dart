import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/contracts/voice_service.dart';
import 'rate_mapping.dart';
import 'tts_engine.dart';
import 'voice_selection.dart';

/// Longest a single utterance may take before [SystemVoiceService.speak] gives up
/// waiting for the engine's completion event (some engines drop it).
typedef SpeechTimeout = Duration Function(String text, double rate);

/// Default [SpeechTimeout]: 5 s plus 150 ms per character at normal speed.
Duration defaultSpeechTimeout(String text, double rate) =>
    Duration(milliseconds: 5000 + (text.length * 150 / rate).round());

/// [VoiceService] backed by the phone's built-in TTS (flutter_tts), fully offline.
///
/// Uses the best installed offline en-GB voice ([VoiceSelection]). When there is
/// none, [hasBritishVoice] is false and [speak] still speaks with the engine's
/// en-GB language setting (or its default voice) so the button is never silent; the
/// UI is expected to explain how to install a British voice.
class SystemVoiceService implements VoiceService {
  /// Creates the service over [engine]. [platform] picks the rate mapping
  /// (defaults to [defaultTargetPlatform]).
  SystemVoiceService({
    required this.engine,
    TargetPlatform? platform,
    this.timeout = defaultSpeechTimeout,
  }) : _platform = platform ?? defaultTargetPlatform {
    _events = engine.events.listen(_onEvent);
  }

  /// The platform TTS engine.
  final TtsEngine engine;

  /// How long one utterance may take.
  final SpeechTimeout timeout;

  final TargetPlatform _platform;
  late final StreamSubscription<TtsEvent> _events;

  Future<TtsVoice?>? _selection;
  TtsVoice? _applied;
  bool _languageFallbackApplied = false;
  Completer<void>? _pending;
  int _generation = 0;

  /// Cancel events still expected from utterances we stopped ourselves; they must
  /// not end the next utterance early.
  int _expectedCancels = 0;

  /// The voice chosen by the last scan (null before the first scan or when none).
  TtsVoice? get selectedVoice => _selectedVoice;
  TtsVoice? _selectedVoice;

  @override
  Future<void> speak(
    String text, {
    double rate = VoiceService.normalRate,
  }) async {
    if (rate.isNaN || rate < 0.1 || rate > 2.0) {
      throw ArgumentError.value(rate, 'rate', 'must be 0.1-2.0');
    }
    final generation = ++_generation;
    await _interrupt();
    if (text.trim().isEmpty || generation != _generation) return;

    await _applyVoice();
    await engine.setRate(TtsRateMapping.toEngine(rate, _platform));
    if (generation != _generation) return; // stopped or replaced meanwhile

    final done = Completer<void>();
    _pending = done;
    final bool started;
    try {
      started = await engine.speak(text);
    } catch (e) {
      debugPrint('SystemVoiceService: speak failed: $e');
      _complete(done);
      return;
    }
    if (!started) _complete(done);

    await done.future.timeout(
      timeout(text, rate),
      onTimeout: () {
        if (identical(_pending, done)) _pending = null;
      },
    );
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _interrupt();
  }

  /// Ends the current utterance (its [speak] completes) and stops the engine.
  Future<void> _interrupt() async {
    final pending = _pending;
    if (pending != null) {
      _expectedCancels = 1;
      _complete(pending);
    }
    try {
      await engine.stop();
    } catch (e) {
      debugPrint('SystemVoiceService: stop failed: $e');
    }
  }

  @override
  Future<bool> hasBritishVoice() async => await rescan() != null;

  @override
  Future<String?> voiceName() async {
    final voice = await rescan();
    return voice == null ? null : VoiceSelection.displayName(voice);
  }

  /// Re-reads the installed voices (the user may have downloaded one in system
  /// settings) and returns the best en-GB voice. The next [speak] uses it.
  Future<TtsVoice?> rescan() => _selection = _scan();

  /// Releases the event subscription. The service must not be used afterwards.
  Future<void> dispose() async {
    await stop();
    await _events.cancel();
  }

  Future<TtsVoice?> _scan() async {
    List<TtsVoice> voices;
    try {
      voices = await engine.voices();
    } catch (e) {
      debugPrint('SystemVoiceService: getVoices failed: $e');
      voices = const [];
    }
    return _selectedVoice = VoiceSelection.best(voices);
  }

  Future<void> _applyVoice() async {
    final voice = await (_selection ??= _scan());
    if (voice != null) {
      if (identical(voice, _applied)) return;
      try {
        if (await engine.setVoice(voice)) {
          _applied = voice;
          return;
        }
      } catch (e) {
        debugPrint('SystemVoiceService: setVoice failed: $e');
      }
    }
    if (_languageFallbackApplied) return;
    try {
      await engine.setLanguage('en-GB');
    } catch (e) {
      debugPrint('SystemVoiceService: setLanguage failed: $e');
    }
    _languageFallbackApplied = true;
  }

  void _onEvent(TtsEvent event) {
    if (event == TtsEvent.cancelled && _expectedCancels > 0) {
      _expectedCancels--;
      return;
    }
    if (event != TtsEvent.cancelled) _expectedCancels = 0;
    final pending = _pending;
    if (pending != null) _complete(pending);
  }

  void _complete(Completer<void> c) {
    if (identical(_pending, c)) _pending = null;
    if (!c.isCompleted) c.complete();
  }
}
