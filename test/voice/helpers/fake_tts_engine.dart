import 'dart:async';

import 'package:uk_pronunciation_coach/voice/tts_engine.dart';

/// Scriptable [TtsEngine] for unit tests.
class FakeTtsEngine implements TtsEngine {
  FakeTtsEngine({
    List<TtsVoice>? voices,
    this.autoComplete = true,
    this.cancelOnStop = true,
  }) : installed = voices ?? [];

  /// What [voices] returns.
  List<TtsVoice> installed;

  /// Emit [TtsEvent.completed] right after [speak].
  bool autoComplete;

  /// Emit [TtsEvent.cancelled] when [stop] interrupts speech (like Android/iOS).
  bool cancelOnStop;

  bool acceptVoice = true;
  bool acceptSpeak = true;
  bool throwOnVoices = false;
  bool throwOnSetVoice = false;
  bool throwOnSetLanguage = false;
  bool throwOnSpeak = false;
  bool throwOnStop = false;

  final spoken = <String>[];
  final rates = <double>[];
  final voicesSet = <TtsVoice>[];
  final languages = <String>[];
  int stopCount = 0;
  int voicesCalls = 0;
  bool speaking = false;

  final _events = StreamController<TtsEvent>.broadcast(sync: true);

  void emit(TtsEvent e) {
    if (e != TtsEvent.cancelled) speaking = false;
    _events.add(e);
  }

  @override
  Stream<TtsEvent> get events => _events.stream;

  @override
  Future<List<TtsVoice>> voices() async {
    voicesCalls++;
    if (throwOnVoices) throw StateError('voices');
    return installed;
  }

  @override
  Future<bool> setVoice(TtsVoice voice) async {
    if (throwOnSetVoice) throw StateError('setVoice');
    if (acceptVoice) voicesSet.add(voice);
    return acceptVoice;
  }

  @override
  Future<bool> setLanguage(String languageTag) async {
    if (throwOnSetLanguage) throw StateError('setLanguage');
    languages.add(languageTag);
    return true;
  }

  @override
  Future<void> setRate(double engineRate) async => rates.add(engineRate);

  @override
  Future<bool> speak(String text) async {
    if (throwOnSpeak) throw StateError('speak');
    if (!acceptSpeak) return false;
    spoken.add(text);
    speaking = true;
    if (autoComplete) scheduleMicrotask(() => emit(TtsEvent.completed));
    return true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    if (throwOnStop) throw StateError('stop');
    if (speaking && cancelOnStop) {
      speaking = false;
      // Delivered later, like the platform channel.
      scheduleMicrotask(() => _events.add(TtsEvent.cancelled));
    }
    speaking = false;
  }
}

TtsVoice androidVoice(
  String name, {
  String locale = 'en-GB',
  String quality = 'normal',
  String latency = 'normal',
  bool network = false,
  String features = '',
}) => TtsVoice.fromMap({
  'name': name,
  'locale': locale,
  'quality': quality,
  'latency': latency,
  'network_required': network ? '1' : '0',
  'features': features,
});

TtsVoice iosVoice(
  String name, {
  String locale = 'en-GB',
  String quality = 'default',
  String? identifier,
}) => TtsVoice.fromMap({
  'name': name,
  'locale': locale,
  'quality': quality,
  'identifier': identifier ?? 'com.apple.voice.$quality.$locale.$name',
  'gender': 'male',
});
