import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/contracts/audio_recorder.dart';
import '../../../core/contracts/errors.dart';
import '../../../core/models/models.dart';
import 'pace_stats.dart';

/// Recordings shorter than this are treated as a tap, not speech.
const Duration _minClip = Duration(milliseconds: 300);

/// Hold-to-record control for the Record section. Records while pressed through the
/// [AudioRecorder] contract and hands each usable clip to [onClip], which must analyse
/// it; the clip is deleted once [onClip] completes, as recordings here are never kept.
///
/// Handles microphone permission (ask, or open settings), clips that are too short or
/// too quiet or noisy, and failures, with a message under the button. [onStart] runs
/// before recording starts so that model speech is stopped first.
class RecordButton extends StatefulWidget {
  /// Creates the control.
  const RecordButton({
    super.key,
    required this.recorder,
    required this.onStart,
    required this.onClip,
    this.enabled = true,
  });

  /// Recorder from the `audioRecorderProvider`.
  final AudioRecorder recorder;

  /// Called before the microphone starts.
  final Future<void> Function() onStart;

  /// Called with each usable clip.
  final Future<void> Function(AudioClip clip) onClip;

  /// When false, presses are ignored.
  final bool enabled;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

enum _Phase { idle, starting, recording, processing }

class _RecordButtonState extends State<RecordButton> {
  _Phase _phase = _Phase.idle;
  bool _pressed = false;
  String? _message;
  MicPermission? _blocked;

  @override
  void dispose() {
    if (_phase == _Phase.starting || _phase == _Phase.recording) {
      unawaited(widget.recorder.cancel());
    }
    super.dispose();
  }

  void _set(VoidCallback change) {
    if (mounted) setState(change);
  }

  Future<void> _press() async {
    if (!widget.enabled || _phase != _Phase.idle) return;
    _pressed = true;
    _set(() {
      _phase = _Phase.starting;
      _message = null;
    });
    try {
      await widget.onStart();
      final permission = await widget.recorder.checkPermission();
      if (permission != MicPermission.granted) {
        _set(() {
          _blocked = permission;
          _phase = _Phase.idle;
        });
        return;
      }
      await widget.recorder.start();
    } on MicPermissionException catch (e) {
      _set(() {
        _blocked = e.state;
        _phase = _Phase.idle;
      });
      return;
    } catch (_) {
      _set(() {
        _message = "Couldn't start the microphone. Please try again.";
        _phase = _Phase.idle;
      });
      return;
    }
    if (!mounted) {
      await widget.recorder.cancel();
      return;
    }
    _set(() {
      _blocked = null;
      _phase = _Phase.recording;
    });
    // The finger lifted while the microphone was starting.
    if (!_pressed) await _finish();
  }

  Future<void> _release() async {
    _pressed = false;
    if (_phase == _Phase.recording) await _finish();
  }

  Future<void> _finish() async {
    _set(() => _phase = _Phase.processing);
    AudioClip? clip;
    try {
      clip = await widget.recorder.stop();
      final problem = _clipProblem(clip);
      if (problem != null) {
        _set(() => _message = problem);
      } else {
        await widget.onClip(clip);
      }
    } catch (_) {
      _set(() => _message = "Couldn't read that recording. Please try again.");
    } finally {
      _set(() => _phase = _Phase.idle);
      if (clip != null) unawaited(widget.recorder.discard(clip));
    }
  }

  static String? _clipProblem(AudioClip clip) {
    if (clip.duration < _minClip) {
      return 'Hold the button down while you read the line.';
    }
    return switch (clip.quality) {
      AudioQuality.ok => null,
      AudioQuality.tooQuiet =>
        'That was too quiet. Hold the phone closer and speak up.',
      AudioQuality.tooNoisy =>
        "It's too noisy here. Try again somewhere quieter.",
    };
  }

  Future<void> _askPermission() async {
    final state = await widget.recorder.requestPermission();
    _set(() {
      _blocked = state == MicPermission.granted ? null : state;
      if (state == MicPermission.granted) {
        _message = 'Microphone on. Hold the button and read the line.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recording = _phase == _Phase.recording;
    final processing = _phase == _Phase.processing;
    final label = switch (_phase) {
      _Phase.recording => "Release when you've finished",
      _Phase.processing => 'Checking...',
      _ => widget.enabled ? 'Hold to record the line' : 'Pick a line to record',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Listener(
          onPointerDown: (_) => _press(),
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: Semantics(
            button: true,
            enabled: widget.enabled,
            label: label,
            child: SizedBox.square(
              dimension: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (recording)
                    StreamBuilder<double>(
                      stream: widget.recorder.level,
                      builder: (context, snap) {
                        final level = (snap.data ?? 0).clamp(0.0, 1.0);
                        return Container(
                          width: 72 + 24 * level,
                          height: 72 + 24 * level,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.error.withValues(alpha: 0.25),
                          ),
                        );
                      },
                    ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: !widget.enabled
                          ? scheme.surfaceContainerHighest
                          : recording
                          ? scheme.error
                          : scheme.primary,
                    ),
                    child: processing
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              color: scheme.onPrimary,
                              strokeWidth: 3,
                            ),
                          )
                        : Icon(
                            recording ? Icons.mic : Icons.mic_none,
                            size: 36,
                            color: !widget.enabled
                                ? scheme.onSurfaceVariant
                                : recording
                                ? scheme.onError
                                : scheme.onPrimary,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelLarge),
        if (_blocked != null) ...[
          const SizedBox(height: 8),
          MicPermissionPrompt(
            state: _blocked!,
            onAsk: _askPermission,
            onSettings: widget.recorder.openPermissionSettings,
          ),
        ] else if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            key: const Key('recordMessage'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

/// Explains a blocked microphone and offers the right action: ask again, or open the
/// system settings when the permission is permanently denied.
class MicPermissionPrompt extends StatelessWidget {
  /// Creates the prompt.
  const MicPermissionPrompt({
    super.key,
    required this.state,
    required this.onAsk,
    required this.onSettings,
  });

  /// [MicPermission.denied] or [MicPermission.permanentlyDenied].
  final MicPermission state;

  /// Shows the system prompt again.
  final Future<void> Function() onAsk;

  /// Opens the app's settings page.
  final Future<bool> Function() onSettings;

  @override
  Widget build(BuildContext context) {
    final permanent = state == MicPermission.permanentlyDenied;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          permanent
              ? 'The microphone is turned off for this app. Turn it on in Settings '
                    'to record. Recordings stay on your phone.'
              : 'The coach needs the microphone to hear you. Recordings stay on '
                    'your phone.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: permanent ? () => onSettings() : () => onAsk(),
          icon: Icon(permanent ? Icons.settings_outlined : Icons.mic_none),
          label: Text(permanent ? 'Open settings' : 'Allow microphone'),
        ),
      ],
    );
  }
}

/// The pace and pause figures for one reading, each with a plain-language hint.
class PaceReadout extends StatelessWidget {
  /// Creates the readout.
  const PaceReadout({super.key, required this.stats, this.title});

  /// Figures to show.
  final PaceStats stats;

  /// Optional heading above the rows (for example "Your reading").
  final String? title;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final wpm = stats.wordsPerMinute;
    final speech = (stats.speech.inMilliseconds / 1000).toStringAsFixed(1);
    final longest = (stats.longestPause.inMilliseconds / 1000).toStringAsFixed(
      1,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) Text(title!, style: text.titleSmall),
        _Row(label: 'Speaking time', value: '$speech s'),
        _Row(
          label: 'Words per minute (estimate)',
          value: wpm == null ? '-' : '${wpm.round()}',
          hint: paceHint(wpm),
        ),
        _Row(
          label: 'Pauses over 0.4 s',
          value: '${stats.pauseCount}',
          hint: pauseHint(stats),
        ),
        _Row(label: 'Longest pause', value: '$longest s'),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: text.bodyMedium)),
              Text(value, style: text.titleSmall),
            ],
          ),
          if (hint != null) Text(hint!, style: text.bodySmall),
        ],
      ),
    );
  }
}
