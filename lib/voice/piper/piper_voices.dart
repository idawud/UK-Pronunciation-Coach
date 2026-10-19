/// Licence review of every Piper en_GB voice in rhasspy/piper-voices (checked
/// 2026-10-19 from each voice's MODEL_CARD, its dataset licence and the licence of
/// the checkpoint it was fine-tuned from). Only [PiperVoiceCandidate.approved]
/// voices may ever ship. Details: docs/licences.md and docs/handoff/C4-voice.md.
library;

/// One Piper voice and the licence verdict for shipping it in a commercial app.
class PiperVoiceCandidate {
  /// Creates a catalogue entry.
  const PiperVoiceCandidate({
    required this.id,
    required this.datasetLicence,
    required this.base,
    required this.approved,
    required this.reason,
    this.displayName,
    this.modelBytes,
    this.attribution,
  });

  /// Piper voice id, e.g. `en_GB-cori-medium`.
  final String id;

  /// Licence of the training recordings.
  final String datasetLicence;

  /// Checkpoint the voice was fine-tuned from, or `scratch`.
  final String base;

  /// Whether commercial redistribution is allowed for the weights and their data.
  final bool approved;

  /// Why it is (not) approved.
  final String reason;

  /// Name shown in Settings (approved voices only).
  final String? displayName;

  /// Size of the `.onnx` file in bytes (approved voices only).
  final int? modelBytes;

  /// Attribution the licence requires, if any.
  final String? attribution;
}

const _lessac =
    'fine-tuned from en_US lessac, trained on the Blizzard 2013 Lessac data, '
    'whose licence is research-only and explicitly excludes commercial speech '
    'products';
const _ryan =
    'fine-tuned from en_US ryan, trained on RyanSpeech (CC BY-NC-SA 4.0, '
    'non-commercial)';

/// Every en_GB voice published in rhasspy/piper-voices, with its verdict.
const List<PiperVoiceCandidate> piperEnGbVoices = [
  PiperVoiceCandidate(
    id: 'en_GB-cori-medium',
    datasetLicence: 'public domain (LibriVox recordings)',
    base: 'scratch',
    approved: true,
    reason: 'trained from scratch on public-domain LibriVox audio',
    displayName: 'Cori (Piper)',
    modelBytes: 63531379,
  ),
  PiperVoiceCandidate(
    id: 'en_GB-cori-high',
    datasetLicence: 'public domain (LibriVox recordings)',
    base: 'scratch',
    approved: true,
    reason: 'trained from scratch on public-domain LibriVox audio',
    displayName: 'Cori HD (Piper)',
    modelBytes: 114219352,
  ),
  PiperVoiceCandidate(
    id: 'en_GB-alan-low',
    datasetLicence: 'Mycroft mimic3 apope dataset, "All Rights Reserved"',
    base: 'en_US-ryan-low',
    approved: false,
    reason: 'dataset all rights reserved; $_ryan',
  ),
  PiperVoiceCandidate(
    id: 'en_GB-alan-medium',
    datasetLicence: 'Mycroft mimic3 apope dataset, "All Rights Reserved"',
    base: 'en_US-lessac-medium',
    approved: false,
    reason: 'dataset all rights reserved; $_lessac',
  ),
  PiperVoiceCandidate(
    id: 'en_GB-alba-medium',
    datasetLicence: 'CC BY 4.0',
    base: 'en_US-lessac-medium',
    approved: false,
    reason: _lessac,
  ),
  PiperVoiceCandidate(
    id: 'en_GB-aru-medium',
    datasetLicence: 'CC BY 4.0',
    base: 'en_US-lessac-medium',
    approved: false,
    reason: _lessac,
  ),
  PiperVoiceCandidate(
    id: 'en_GB-jenny_dioco-medium',
    datasetLicence: 'Jenny (Dioco): commercial use allowed with attribution',
    base: 'en_US-lessac-medium',
    approved: false,
    reason: _lessac,
  ),
  PiperVoiceCandidate(
    id: 'en_GB-northern_english_male-medium',
    datasetLicence: 'CC BY-SA 4.0 (OpenSLR 83)',
    base: 'en_US-lessac-medium',
    approved: false,
    reason: '$_lessac; also a Northern accent, not SSBE',
  ),
  PiperVoiceCandidate(
    id: 'en_GB-semaine-medium',
    datasetLicence: 'CC BY-NC-SA 4.0',
    base: 'en_US-lessac-medium',
    approved: false,
    reason: 'dataset non-commercial; $_lessac',
  ),
  PiperVoiceCandidate(
    id: 'en_GB-southern_english_female-low',
    datasetLicence: 'CC BY-SA 4.0 (OpenSLR 83)',
    base: 'en_US-ryan-low',
    approved: false,
    reason: _ryan,
  ),
  PiperVoiceCandidate(
    id: 'en_GB-vctk-medium',
    datasetLicence: 'CC BY 4.0',
    base: 'en_US-lessac-medium',
    approved: false,
    reason: _lessac,
  ),
];

/// The voices that may ship.
List<PiperVoiceCandidate> get approvedPiperVoices => [
  for (final v in piperEnGbVoices)
    if (v.approved) v,
];
