import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/contracts/contracts.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';

/// Recordings shorter than this are treated as a tap, not a word.
const Duration minWordClip = Duration(milliseconds: 300);

/// Hold-to-record control for a single word: records while pressed (through the
/// [AudioRecorder] contract, ignoring `silenceDetected`), then scores the clip with
/// [PhonemeRecognizer] and `PronunciationScorer.scoreWord` and reports the result.
///
/// Handles microphone permission (ask / open settings), too-short, too-quiet and
/// too-noisy clips and scoring errors with a message under the button.
/// U2 builds its own tap-to-record control for passages; the two could share a
/// widget later.
class HoldToRecordButton extends ConsumerStatefulWidget {
  /// Creates the control for [word].
  const HoldToRecordButton({
    super.key,
    required this.word,
    required this.onScored,
    this.tier = ModelTier.full,
  });

  /// The word being said (passage index and expected sounds).
  final WordSpec word;

  /// Called with each scored try.
  final ValueChanged<WordResult> onScored;

  /// Tier to load when no model is loaded yet (falls back to light).
  final ModelTier tier;

  @override
  ConsumerState<HoldToRecordButton> createState() => _HoldToRecordButtonState();
}

enum _RecState { idle, starting, recording, scoring }

class _HoldToRecordButtonState extends ConsumerState<HoldToRecordButton> {
  late final AudioRecorder _recorder;
  _RecState _state = _RecState.idle;
  bool _pressed = false;
  String? _message;
  MicPermission? _blocked;

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(audioRecorderProvider);
  }

  @override
  void dispose() {
    if (_state == _RecState.starting || _state == _RecState.recording) {
      unawaited(_recorder.cancel());
    }
    super.dispose();
  }

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  Future<void> _press() async {
    if (_state != _RecState.idle) return;
    _pressed = true;
    _set(() {
      _state = _RecState.starting;
      _message = null;
    });
    try {
      final perm = await _recorder.checkPermission();
      if (perm != MicPermission.granted) {
        _set(() {
          _blocked = perm;
          _state = _RecState.idle;
        });
        return;
      }
      await _recorder.start();
    } on MicPermissionException catch (e) {
      _set(() {
        _blocked = e.state;
        _state = _RecState.idle;
      });
      return;
    } catch (_) {
      _set(() {
        _message = "Couldn't start the microphone. Please try again.";
        _state = _RecState.idle;
      });
      return;
    }
    if (!mounted) {
      await _recorder.cancel();
      return;
    }
    _set(() {
      _blocked = null;
      _state = _RecState.recording;
    });
    if (!_pressed) await _finish();
  }

  Future<void> _release() async {
    _pressed = false;
    if (_state == _RecState.recording) await _finish();
  }

  Future<void> _finish() async {
    _set(() => _state = _RecState.scoring);
    try {
      final clip = await _recorder.stop();
      final problem = _clipProblem(clip);
      if (problem != null) {
        _set(() {
          _message = problem;
          _state = _RecState.idle;
        });
        return;
      }
      final recognizer = ref.read(phonemeRecognizerProvider);
      if (recognizer.loadedTier == null) {
        try {
          await recognizer.load(widget.tier);
        } on ModelNotAvailableException {
          await recognizer.load(ModelTier.light);
        }
      }
      final posteriors = await recognizer.recognise(clip);
      final result = ref
          .read(pronunciationScorerProvider)
          .scoreWord(widget.word, posteriors);
      if (!mounted) return;
      setState(() => _state = _RecState.idle);
      widget.onScored(result);
    } catch (_) {
      _set(() {
        _message = "Couldn't score that. Please try again.";
        _state = _RecState.idle;
      });
    }
  }

  static String? _clipProblem(AudioClip clip) {
    if (clip.duration < minWordClip) {
      return 'Hold the button down while you say the word.';
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
    final state = await _recorder.requestPermission();
    _set(() {
      _blocked = state == MicPermission.granted ? null : state;
      if (state == MicPermission.granted) {
        _message = 'Microphone on. Hold the button and say the word.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recording = _state == _RecState.recording;
    final scoring = _state == _RecState.scoring;
    final label = switch (_state) {
      _RecState.recording => "Release when you've finished",
      _RecState.scoring => 'Scoring...',
      _ => 'Hold to say "${widget.word.text}"',
    };
    final button = Listener(
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox.square(
          dimension: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (recording)
                StreamBuilder<double>(
                  stream: _recorder.level,
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
                  color: recording ? scheme.error : scheme.primary,
                ),
                child: scoring
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
                        color: recording ? scheme.onError : scheme.onPrimary,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelLarge),
        if (_blocked != null) ...[
          const SizedBox(height: 8),
          _PermissionPrompt(
            state: _blocked!,
            onAsk: _askPermission,
            onSettings: _recorder.openPermissionSettings,
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

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({
    required this.state,
    required this.onAsk,
    required this.onSettings,
  });

  final MicPermission state;
  final Future<void> Function() onAsk;
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
          onPressed: permanent ? onSettings : onAsk,
          icon: Icon(permanent ? Icons.settings_outlined : Icons.mic_none),
          label: Text(permanent ? 'Open settings' : 'Allow microphone'),
        ),
      ],
    );
  }
}
