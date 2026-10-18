import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'audio_clip.freezed.dart';
part 'audio_clip.g.dart';

/// A finished recording: 16 kHz mono 16-bit PCM WAV in app-private storage.
@freezed
abstract class AudioClip with _$AudioClip {
  /// - [path]: absolute path of the WAV file.
  /// - [sampleRate]: always 16000 for recordings made by the app.
  /// - [duration]: length of the audio.
  /// - [quality]: result of the pre-scoring check (A1); UI offers a retry when not ok.
  /// - [peakDbfs]: peak level in dBFS (<= 0), if measured.
  /// - [snrDb]: estimated signal-to-noise ratio in dB, if measured.
  const factory AudioClip({
    required String path,
    @Default(16000) int sampleRate,
    required Duration duration,
    @Default(AudioQuality.ok) AudioQuality quality,
    double? peakDbfs,
    double? snrDb,
  }) = _AudioClip;

  /// Decodes from JSON. [duration] is stored in microseconds.
  factory AudioClip.fromJson(Map<String, dynamic> json) =>
      _$AudioClipFromJson(json);
}
