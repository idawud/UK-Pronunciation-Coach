import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/models/enums.dart';
import 'mic.dart';
import 'wav.dart';

/// [MicSource] that "records" a fixed clip: for host tests, on-device tests and
/// I1's e2e journeys (never a real microphone).
///
/// Emits [pcm] (mono 16-bit little-endian at the requested rate) in blocks of
/// [block], paced in real time when [realTime] is true. After the clip it emits
/// digital silence until stopped when [silenceAfter] is true, otherwise it just
/// waits.
class FixtureMicSource implements MicSource {
  /// Plays raw PCM16 bytes.
  FixtureMicSource(
    this.pcm, {
    this.block = const Duration(milliseconds: 20),
    this.realTime = true,
    this.silenceAfter = true,
    this.startDelay = Duration.zero,
  });

  /// Plays the samples of a 16-bit PCM WAV file (must be 16 kHz).
  factory FixtureMicSource.wav(
    Uint8List wavBytes, {
    Duration block = const Duration(milliseconds: 20),
    bool realTime = true,
    bool silenceAfter = true,
  }) {
    final audio = decodeWav(wavBytes);
    if (audio.sampleRate != recordingSampleRate) {
      throw FormatException('Fixture must be 16 kHz, is ${audio.sampleRate}');
    }
    final bytes = encodeWav(audio.samples).sublist(44);
    return FixtureMicSource(
      bytes,
      block: block,
      realTime: realTime,
      silenceAfter: silenceAfter,
    );
  }

  /// The clip as PCM16 bytes.
  final Uint8List pcm;

  /// Audio per emitted block.
  final Duration block;

  /// Pace blocks in real time (true) or emit as fast as possible.
  final bool realTime;

  /// Emit silence after the clip until stopped.
  final bool silenceAfter;

  /// Simulated plug-in start-up time.
  final Duration startDelay;

  /// Number of [start] calls.
  int starts = 0;

  /// True after [dispose].
  bool disposed = false;

  StreamController<Uint8List>? _controller;
  Timer? _timer;

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async {
    if (_controller != null) throw StateError('Already started');
    if (startDelay > Duration.zero) await Future<void>.delayed(startDelay);
    starts++;
    final controller = StreamController<Uint8List>();
    _controller = controller;
    final blockBytes = math.max(
      2,
      block.inMicroseconds * sampleRate ~/ 1000000 * 2,
    );
    var offset = 0;
    void emit() {
      if (controller.isClosed) return;
      if (offset < pcm.length) {
        final end = math.min(offset + blockBytes, pcm.length);
        controller.add(Uint8List.sublistView(pcm, offset, end));
        offset = end;
      } else if (silenceAfter) {
        controller.add(Uint8List(blockBytes));
      }
    }

    if (realTime) {
      _timer = Timer.periodic(block, (_) => emit());
    } else {
      // Deliver the whole clip in one go on the next event-loop turn.
      Timer.run(() {
        while (offset < pcm.length) {
          emit();
        }
      });
    }
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    final c = _controller;
    _controller = null;
    if (c != null) await c.close();
  }

  @override
  Future<void> dispose() async {
    await stop();
    disposed = true;
  }
}

/// [MicPermissions] with a fixed answer (tests and fixture builds).
class FixedMicPermissions implements MicPermissions {
  /// Starts in [state]; [afterRequest] is what a prompt would return.
  FixedMicPermissions([
    this.state = MicPermission.granted,
    MicPermission? afterRequest,
  ]) : afterRequest = afterRequest ?? state;

  /// Current state.
  MicPermission state;

  /// State after a prompt.
  MicPermission afterRequest;

  /// Times the prompt was shown.
  int prompts = 0;

  /// Times the settings page was opened.
  int settingsOpened = 0;

  @override
  Future<MicPermission> status() async => state;

  @override
  Future<MicPermission> request() async {
    if (state != MicPermission.denied) return state;
    prompts++;
    return state = afterRequest;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}
