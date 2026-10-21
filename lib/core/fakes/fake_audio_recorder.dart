import 'dart:async';

import '../contracts/audio_recorder.dart';
import '../contracts/errors.dart';
import '../models/models.dart';
import 'sample_data.dart';

/// Working in-memory [AudioRecorder]: no microphone, no files.
///
/// While recording it emits [levels] every [levelInterval], then (if
/// [emitSilenceAfterLevels]) fires `silenceDetected` once. [stop] returns [clip]
/// (by default as long as the canned river reading). Pass `segments` to fix what
/// [speechSegments] returns.
class FakeAudioRecorder implements AudioRecorder {
  /// Creates a fake recorder. Tweak the public fields to simulate states.
  FakeAudioRecorder({
    this.permission = MicPermission.granted,
    this.permissionAfterRequest = MicPermission.granted,
    AudioClip? clip,
    List<double>? levels,
    this.levelInterval = const Duration(milliseconds: 50),
    this.emitSilenceAfterLevels = true,
    this._segments,
  }) : clip =
           clip ??
           AudioClip(
             path: '/fake/recordings/sample.wav',
             duration: riverPosteriors.duration,
           ),
       levels =
           levels ??
           [for (var i = 0; i < 20; i++) 0.2 + 0.6 * ((i * 7) % 10) / 10];

  /// Permission returned by [checkPermission].
  MicPermission permission;

  /// Permission after [requestPermission] (when not permanently denied).
  MicPermission permissionAfterRequest;

  /// Clip returned by [stop] (set `quality` to simulate too quiet / too noisy).
  AudioClip clip;

  /// Level values emitted while recording, in order.
  List<double> levels;

  /// Time between level values.
  Duration levelInterval;

  /// Whether `silenceDetected` fires after the last level value.
  bool emitSilenceAfterLevels;

  /// Number of times [openPermissionSettings] was called.
  int settingsOpened = 0;

  /// Number of completed [start] calls.
  int startCount = 0;

  /// Clips passed to [discard], in order (the fake has no files to delete).
  final List<AudioClip> discarded = [];

  final List<Segment>? _segments;
  final _level = StreamController<double>.broadcast();
  final _silence = StreamController<void>.broadcast();
  Timer? _timer;
  bool _recording = false;
  bool _disposed = false;

  @override
  Future<MicPermission> checkPermission() async => permission;

  @override
  Future<MicPermission> requestPermission() async {
    if (permission == MicPermission.permanentlyDenied) return permission;
    return permission = permissionAfterRequest;
  }

  @override
  Future<bool> openPermissionSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  bool get isRecording => _recording;

  @override
  Future<void> start() async {
    _checkNotDisposed();
    if (_recording) throw StateError('Already recording');
    if (permission != MicPermission.granted) {
      throw MicPermissionException(permission);
    }
    _recording = true;
    startCount++;
    var i = 0;
    _timer = Timer.periodic(levelInterval, (t) {
      if (i < levels.length) {
        _level.add(levels[i++].clamp(0.0, 1.0));
      } else {
        t.cancel();
        if (emitSilenceAfterLevels) _silence.add(null);
      }
    });
  }

  @override
  Future<AudioClip> stop() async {
    _checkNotDisposed();
    if (!_recording) throw StateError('Not recording');
    _halt();
    return clip;
  }

  @override
  Future<void> cancel() async => _halt();

  void _halt() {
    _timer?.cancel();
    _timer = null;
    _recording = false;
  }

  @override
  Future<void> discard(AudioClip clip) async => discarded.add(clip);

  @override
  Stream<double> get level => _level.stream;

  @override
  Stream<void> get silenceDetected => _silence.stream;

  @override
  Future<List<Segment>> speechSegments(AudioClip clip) async {
    final d = clip.duration;
    final raw =
        _segments ??
        [
          Segment(
            start: const Duration(milliseconds: 200),
            end: d - const Duration(milliseconds: 200),
          ),
        ];
    return [
      for (final s in raw)
        if (s.start < d && s.end > Duration.zero && s.start < s.end)
          Segment(
            start: s.start < Duration.zero ? Duration.zero : s.start,
            end: s.end > d ? d : s.end,
          ),
    ]..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Future<void> dispose() async {
    _halt();
    _disposed = true;
    await _level.close();
    await _silence.close();
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('Recorder disposed');
  }
}
