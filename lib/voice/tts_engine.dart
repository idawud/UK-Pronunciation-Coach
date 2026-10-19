/// Thin seam over the platform text-to-speech engine, so [SystemVoiceService] can be
/// tested with a fake. The real adapter is `FlutterTtsEngine` (flutter_tts).
library;

/// One installed system voice, as reported by the platform.
class TtsVoice {
  /// Creates a voice description.
  const TtsVoice({
    required this.name,
    required this.locale,
    this.identifier,
    this.quality,
    this.latency,
    this.networkRequired = false,
    this.features = const [],
    this.raw = const {},
  });

  /// Parses one entry of flutter_tts `getVoices` (Android or iOS shape).
  ///
  /// Android: `name`, `locale`, `quality` ("very high" ... "very low"), `latency`,
  /// `network_required` ("1"/"0"), `features` (tab-separated).
  /// iOS: `name`, `locale`, `quality` ("default", "enhanced", "premium"),
  /// `identifier`, `gender`.
  factory TtsVoice.fromMap(Map<Object?, Object?> map) {
    String? str(String key) {
      return map[key]?.toString();
    }

    final features = str('features');
    return TtsVoice(
      name: str('name') ?? '',
      locale: str('locale') ?? '',
      identifier: str('identifier'),
      quality: str('quality'),
      latency: str('latency'),
      networkRequired: str('network_required') == '1',
      features: features == null || features.isEmpty
          ? const []
          : features.split('\t'),
      raw: {
        for (final e in map.entries)
          if (e.key != null && e.value != null)
            e.key.toString(): e.value.toString(),
      },
    );
  }

  /// Platform voice name (Android: `en-gb-x-rjs-local`; iOS: `Daniel`).
  final String name;

  /// BCP-47-ish locale tag, e.g. `en-GB` (`en_GB` is also accepted).
  final String locale;

  /// iOS voice identifier, e.g. `com.apple.voice.enhanced.en-GB.Daniel`.
  final String? identifier;

  /// Platform quality label (see [TtsVoice.fromMap]).
  final String? quality;

  /// Android latency label ("very low" ... "very high").
  final String? latency;

  /// Android: the voice synthesises on a server (never used: the app is offline).
  final bool networkRequired;

  /// Android voice features, e.g. `notInstalled`, `networkTts`.
  final List<String> features;

  /// The original map, passed back to the platform by `setVoice`.
  final Map<String, String> raw;

  @override
  String toString() => 'TtsVoice($name, $locale, quality: $quality)';
}

/// Something the engine reports about the current utterance.
enum TtsEvent {
  /// Speech finished normally.
  completed,

  /// Speech was cancelled (stop or interruption).
  cancelled,

  /// The engine failed to speak.
  error,
}

/// The platform TTS engine, reduced to what [SystemVoiceService] needs.
abstract interface class TtsEngine {
  /// Installed voices; empty when the platform cannot list them.
  Future<List<TtsVoice>> voices();

  /// Selects [voice]; returns false when the platform rejected it.
  Future<bool> setVoice(TtsVoice voice);

  /// Selects a language (fallback when no voice can be chosen); returns success.
  Future<bool> setLanguage(String languageTag);

  /// Sets the flutter_tts speech rate (already mapped for the platform, see
  /// `TtsRateMapping`).
  Future<void> setRate(double engineRate);

  /// Starts speaking [text] and returns at once; returns false when the engine
  /// refused. Completion arrives on [events].
  Future<bool> speak(String text);

  /// Stops speaking.
  Future<void> stop();

  /// Completion, cancellation and error events for utterances.
  Stream<TtsEvent> get events;
}
