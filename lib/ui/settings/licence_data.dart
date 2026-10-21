/// Models, dictionaries, voices, content and fonts that ship with the app, shown on the
/// Licences page. Seeded from the "Shipped in the app" table in docs/licences.md: keep
/// the two in step when a component lands or changes. Dart packages are listed
/// separately by Flutter's `showLicensePage`.
library;

/// Kind of shipped component, in the order the Licences page shows them.
enum LicenceKind {
  /// Speech models.
  model('Speech models'),

  /// Pronunciation dictionaries.
  dictionary('Dictionaries'),

  /// Text-to-speech voices.
  voice('Voices'),

  /// Reading passages.
  content('Reading passages'),

  /// Native engines bundled as libraries.
  engine('Engines'),

  /// Fonts.
  font('Fonts');

  const LicenceKind(this.title);

  /// Section heading.
  final String title;
}

/// One shipped component and its licence.
class LicenceEntry {
  /// Creates an entry.
  const LicenceEntry({
    required this.kind,
    required this.name,
    required this.licence,
    required this.source,
    this.note,
  });

  /// Section.
  final LicenceKind kind;

  /// What it is.
  final String name;

  /// Licence name (SPDX-style where possible).
  final String licence;

  /// Where it comes from.
  final String source;

  /// Attribution or other note, if any.
  final String? note;
}

/// Every shipped model, dictionary, voice, content set, engine and font.
const List<LicenceEntry> shippedLicences = [
  LicenceEntry(
    kind: LicenceKind.model,
    name: 'Light phoneme model (bundled)',
    licence: 'Apache-2.0',
    source:
        'facebook/wav2vec2-lv-60-espeak-cv-ft, reduced to 6 layers and '
        'distilled for this app',
    note:
        'Trained in part on the CSTR VCTK Corpus (University of Edinburgh), '
        'CC BY 4.0.',
  ),
  LicenceEntry(
    kind: LicenceKind.model,
    name: 'Full phoneme model (optional download)',
    licence: 'Apache-2.0',
    source: 'facebook/wav2vec2-lv-60-espeak-cv-ft, converted to ONNX',
  ),
  LicenceEntry(
    kind: LicenceKind.model,
    name: 'Silero VAD (speech detection)',
    licence: 'MIT',
    source: 'snakers4/silero-vad v6.2',
    note: 'Copyright (c) 2020-present Silero Team.',
  ),
  LicenceEntry(
    kind: LicenceKind.dictionary,
    name: 'Britfone British English pronunciation dictionary',
    licence: 'MIT',
    source: 'Britfone',
  ),
  LicenceEntry(
    kind: LicenceKind.voice,
    name: "Your phone's English (UK) text-to-speech voice",
    licence: 'Provided by your device',
    source: 'Android or iOS system voices; not bundled with the app',
  ),
  LicenceEntry(
    kind: LicenceKind.content,
    name: 'Passages for reading practice',
    licence: 'Original or public domain',
    source: 'Written or selected for this app',
  ),
  LicenceEntry(
    kind: LicenceKind.engine,
    name: 'ONNX Runtime',
    licence: 'MIT',
    source: 'Microsoft',
  ),
  LicenceEntry(
    kind: LicenceKind.engine,
    name: 'Java core library backports (Android)',
    licence: 'GPL-2.0 with the Classpath Exception',
    source: 'Google desugar_jdk_libs (from OpenJDK)',
    note:
        'Used by the notifications plug-in for daily reminders. Source: '
        'github.com/google/desugar_jdk_libs',
  ),
  LicenceEntry(
    kind: LicenceKind.font,
    name: 'Material Icons',
    licence: 'Apache-2.0',
    source: 'Google, bundled by Flutter',
  ),
  LicenceEntry(
    kind: LicenceKind.font,
    name: 'Text fonts',
    licence: 'Provided by your device',
    source:
        'System fonts (Roboto on Android, San Francisco on iOS); not bundled',
  ),
];
