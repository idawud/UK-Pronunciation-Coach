import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

/// [TtsEngine] over the flutter_tts plug-in (MIT): Android `TextToSpeech`, iOS
/// `AVSpeechSynthesizer`. Everything stays on the device; network voices are never
/// selected (see `VoiceSelection`).
///
/// `speak` does not use flutter_tts `awaitSpeakCompletion`, because on iOS a
/// cancelled utterance never completes that future; completion comes from the
/// plug-in's handlers instead.
class FlutterTtsEngine implements TtsEngine {
  /// Creates the adapter; [tts] is injectable for tests.
  FlutterTtsEngine({FlutterTts? tts, TargetPlatform? platform})
    : _tts = tts ?? FlutterTts(),
      _platform = platform ?? defaultTargetPlatform {
    _tts
      ..setCompletionHandler(() => _events.add(TtsEvent.completed))
      ..setCancelHandler(() => _events.add(TtsEvent.cancelled))
      ..setErrorHandler((Object? _) => _events.add(TtsEvent.error));
  }

  final FlutterTts _tts;
  final TargetPlatform _platform;
  final _events = StreamController<TtsEvent>.broadcast();
  Future<void>? _setup;

  /// iOS: play through the speaker even in silent mode and duck other audio;
  /// a shared audio session so the recorder (A1) can take it over.
  Future<void> _ensureSetup() => _setup ??= () async {
    try {
      await _tts.awaitSpeakCompletion(false);
      if (_platform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ], IosTextToSpeechAudioMode.spokenAudio);
      }
    } catch (e) {
      debugPrint('FlutterTtsEngine: setup failed: $e');
    }
  }();

  @override
  Stream<TtsEvent> get events => _events.stream;

  @override
  Future<List<TtsVoice>> voices() async {
    await _ensureSetup();
    final Object? list = await _tts.getVoices;
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map) TtsVoice.fromMap(item),
    ];
  }

  @override
  Future<bool> setVoice(TtsVoice voice) async {
    await _ensureSetup();
    final Object? r = await _tts.setVoice(
      voice.raw.isEmpty
          ? {'name': voice.name, 'locale': voice.locale}
          : voice.raw,
    );
    return _ok(r);
  }

  @override
  Future<bool> setLanguage(String languageTag) async {
    await _ensureSetup();
    return _ok(await _tts.setLanguage(languageTag));
  }

  @override
  Future<void> setRate(double engineRate) async {
    await _ensureSetup();
    await _tts.setSpeechRate(engineRate);
  }

  @override
  Future<bool> speak(String text) async {
    await _ensureSetup();
    return _ok(await _tts.speak(text));
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }

  static bool _ok(Object? r) => r == 1 || r == true;
}
