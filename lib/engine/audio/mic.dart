import 'dart:async';
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:record/record.dart' as rec;

import '../../core/models/enums.dart';

/// Thin seam over the microphone plug-in so the recorder can be tested on a host
/// with fixture audio.
abstract interface class MicSource {
  /// Starts capturing mono little-endian 16-bit PCM at [sampleRate] and returns the
  /// byte stream. Completes once capture has begun.
  Future<Stream<Uint8List>> start({required int sampleRate});

  /// Stops capturing; the stream from [start] closes.
  Future<void> stop();

  /// Releases the plug-in.
  Future<void> dispose();
}

/// Thin seam over the permission plug-in.
abstract interface class MicPermissions {
  /// Current state, without prompting.
  Future<MicPermission> status();

  /// Shows the system prompt (when the OS still allows it) and returns the result.
  Future<MicPermission> request();

  /// Opens the app's system settings page.
  Future<bool> openSettings();
}

/// [MicSource] on the `record` plug-in (BSD-3-Clause), streaming raw PCM.
///
/// Auto-gain, echo cancellation and noise suppression are off: they change the
/// spectrum the phoneme model scores and hide real noise from the quality check.
class RecordMicSource implements MicSource {
  /// Wraps [recorder] (a new `record` recorder by default).
  RecordMicSource([rec.AudioRecorder? recorder])
    : _recorder = recorder ?? rec.AudioRecorder();

  final rec.AudioRecorder _recorder;

  /// The `record` configuration used for [sampleRate].
  static rec.RecordConfig configFor(int sampleRate) => rec.RecordConfig(
    encoder: rec.AudioEncoder.pcm16bits,
    sampleRate: sampleRate,
    numChannels: 1,
    androidConfig: const rec.AndroidRecordConfig(
      audioSource: rec.AndroidAudioSource.voiceRecognition,
    ),
    // A phone call or Siri stops the recording; the user re-records.
    audioInterruption: rec.AudioInterruptionMode.pause,
  );

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) =>
      _recorder.startStream(configFor(sampleRate));

  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

/// Maps a `permission_handler` status to [MicPermission].
MicPermission micPermissionFrom(ph.PermissionStatus status) {
  switch (status) {
    case ph.PermissionStatus.granted:
    case ph.PermissionStatus.limited:
    case ph.PermissionStatus.provisional:
      return MicPermission.granted;
    case ph.PermissionStatus.permanentlyDenied:
    case ph.PermissionStatus.restricted:
      return MicPermission.permanentlyDenied;
    case ph.PermissionStatus.denied:
      return MicPermission.denied;
  }
}

/// [MicPermissions] on `permission_handler` (MIT). The three plug-in calls can be
/// replaced for tests.
class PermissionHandlerMicPermissions implements MicPermissions {
  /// Uses `Permission.microphone` unless overridden.
  PermissionHandlerMicPermissions({
    Future<ph.PermissionStatus> Function()? readStatus,
    Future<ph.PermissionStatus> Function()? requestStatus,
    Future<bool> Function()? openAppSettings,
  }) : _status = readStatus ?? (() => ph.Permission.microphone.status),
       _request = requestStatus ?? ph.Permission.microphone.request,
       _open = openAppSettings ?? ph.openAppSettings;

  final Future<ph.PermissionStatus> Function() _status;
  final Future<ph.PermissionStatus> Function() _request;
  final Future<bool> Function() _open;

  @override
  Future<MicPermission> status() async => micPermissionFrom(await _status());

  @override
  Future<MicPermission> request() async {
    final now = await status();
    // Never prompt when it would be pointless (already granted) or impossible
    // (the OS no longer shows the prompt).
    if (now != MicPermission.denied) return now;
    return micPermissionFrom(await _request());
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await _open();
    } on Exception {
      return false;
    }
  }
}
