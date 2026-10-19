import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';

/// Full-model download state: the current status, then every change.
final modelDownloadProvider = StreamProvider<ModelDownloadProgress>((
  ref,
) async* {
  final recognizer = ref.watch(phonemeRecognizerProvider);
  yield recognizer.downloadStatus;
  yield* recognizer.downloadProgress;
});

/// Whether the full model is on the device; rechecked when the download state changes.
final fullTierAvailableProvider = FutureProvider<bool>((ref) {
  ref.watch(modelDownloadProvider.select((p) => p.value?.state));
  return ref.watch(phonemeRecognizerProvider).isTierAvailable(ModelTier.full);
});

/// The tier the recognizer recommends for this device.
final recommendedTierProvider = FutureProvider<ModelTier>(
  (ref) => ref.watch(phonemeRecognizerProvider).recommendedTier(),
);

/// Whether an offline British voice is installed, and its name.
class VoiceStatus {
  /// Creates the status.
  const VoiceStatus({required this.hasBritishVoice, this.name});

  /// True when an en-GB voice is installed.
  final bool hasBritishVoice;

  /// Voice display name, if any.
  final String? name;
}

/// The British voice check. Invalidate to check again.
final voiceStatusProvider = FutureProvider<VoiceStatus>((ref) async {
  final voice = ref.watch(voiceServiceProvider);
  final has = await voice.hasBritishVoice();
  return VoiceStatus(
    hasBritishVoice: has,
    name: has ? await voice.voiceName() : null,
  );
});

/// Formats [bytes] as whole megabytes, e.g. "320 MB".
String formatMegabytes(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';
