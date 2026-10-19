import 'tts_engine.dart';

/// Picks the best installed offline en-GB voice.
///
/// Rules (see docs/handoff/C4-voice.md):
/// 1. Only en-GB voices (`en-GB`, `en_GB`, `en-GB-...`, `eng-GBR`).
/// 2. Never voices that need the network (`network_required`, the `networkTts`
///    feature or a `-network` name) or are not downloaded (`notInstalled`).
/// 3. Never iOS Personal Voices (the user's own cloned voice).
/// 4. Highest quality first: iOS premium > enhanced > default; Android very high >
///    high > normal > unknown > low > very low. iOS Eloquence voices (Eddy, Flo,
///    Grandma...) and legacy novelty voices rank below other default-quality voices.
/// 5. Then lower Android latency, then name (stable order).
abstract final class VoiceSelection {
  /// Whether [locale] names British English.
  static bool isBritish(String locale) {
    final l = locale.toLowerCase().replaceAll('_', '-');
    return l == 'en-gb' ||
        l.startsWith('en-gb-') ||
        l == 'eng-gbr' ||
        l == 'en-uk';
  }

  /// Whether [voice] can speak without a network connection.
  static bool isOffline(TtsVoice voice) {
    if (voice.networkRequired) return false;
    if (voice.features.contains('notInstalled')) return false;
    if (voice.features.contains('networkTts') &&
        !voice.features.contains('embeddedTts')) {
      return false;
    }
    return !voice.name.toLowerCase().endsWith('-network');
  }

  static bool _isExcluded(TtsVoice voice) {
    final id = (voice.identifier ?? '').toLowerCase();
    return id.contains('personalvoice') || voice.name.isEmpty;
  }

  /// Usable en-GB voices, best first.
  static List<TtsVoice> rank(Iterable<TtsVoice> voices) {
    final usable = voices
        .where((v) => isBritish(v.locale) && isOffline(v) && !_isExcluded(v))
        .toList();
    usable.sort((a, b) {
      final q = _qualityScore(b).compareTo(_qualityScore(a));
      if (q != 0) return q;
      final lat = _latencyScore(b).compareTo(_latencyScore(a));
      if (lat != 0) return lat;
      return a.name.compareTo(b.name);
    });
    return usable;
  }

  /// The best usable en-GB voice, or null when there is none.
  static TtsVoice? best(Iterable<TtsVoice> voices) {
    final ranked = rank(voices);
    return ranked.isEmpty ? null : ranked.first;
  }

  static int _qualityScore(TtsVoice v) {
    final base = switch ((v.quality ?? '').toLowerCase()) {
      'premium' => 60,
      'very high' => 60,
      'enhanced' => 50,
      'high' => 50,
      'normal' => 40,
      'default' => 40,
      'low' => 20,
      'very low' => 10,
      _ => 30,
    };
    final id = (v.identifier ?? '').toLowerCase();
    // Eloquence and the old novelty / MacinTalk voices sound robotic.
    final legacy =
        id.contains('eloquence') || id.contains('speech.synthesis.voice');
    return legacy ? base - 5 : base;
  }

  static int _latencyScore(TtsVoice v) =>
      switch ((v.latency ?? '').toLowerCase()) {
        'very low' => 4,
        'low' => 3,
        'normal' => 2,
        'high' => 1,
        'very high' => 0,
        _ => 2,
      };

  static final _androidName = RegExp(
    r'^en[-_]gb[-_]x[-_]([a-z0-9]+)',
    caseSensitive: false,
  );

  /// A name for the Settings screen: iOS `Daniel (Enhanced)`; Android
  /// `en-gb-x-rjs-local` -> `English (UK) RJS`, `en-GB-language` -> `English (UK)`.
  static String displayName(TtsVoice v) {
    final m = _androidName.firstMatch(v.name);
    if (m != null) return 'English (UK) ${m.group(1)!.toUpperCase()}';
    if (v.name.toLowerCase() == 'en-gb-language') return 'English (UK)';
    return switch ((v.quality ?? '').toLowerCase()) {
      'premium' => '${v.name} (Premium)',
      'enhanced' => '${v.name} (Enhanced)',
      _ => v.name,
    };
  }
}
