import 'package:flutter/material.dart';

/// Big round record / stop button.
///
/// Tap mode (Read screen): pass [onTap]. Hold-to-record mode (Fix a word): pass
/// [onHoldStart] and [onHoldEnd]; recording runs while the finger is down. Colours
/// come from the theme: primary when idle, error while [recording].
class RecordButton extends StatelessWidget {
  /// Creates the button.
  const RecordButton({
    super.key,
    required this.recording,
    this.onTap,
    this.onHoldStart,
    this.onHoldEnd,
    this.size = 88,
    this.enabled = true,
  });

  /// Whether a recording is running (shows a stop icon in tap mode).
  final bool recording;

  /// Called on tap (tap mode).
  final VoidCallback? onTap;

  /// Called when the finger goes down (hold mode).
  final VoidCallback? onHoldStart;

  /// Called when the finger lifts or the gesture is cancelled (hold mode).
  final VoidCallback? onHoldEnd;

  /// Diameter in logical pixels.
  final double size;

  /// False greys the button out and ignores input.
  final bool enabled;

  bool get _holdMode => onHoldStart != null || onHoldEnd != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = !enabled
        ? scheme.onSurface.withValues(alpha: 0.12)
        : recording
        ? scheme.error
        : scheme.primary;
    final foreground = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : recording
        ? scheme.onError
        : scheme.onPrimary;
    final label = _holdMode
        ? (recording ? 'Recording. Release to stop' : 'Hold to record')
        : (recording ? 'Stop recording' : 'Start recording');
    final icon = recording && !_holdMode ? Icons.stop_rounded : Icons.mic;

    Widget button = Material(
      color: background,
      shape: const CircleBorder(),
      elevation: recording ? 6 : 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled && !_holdMode ? onTap : null,
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, size: size * 0.45, color: foreground),
        ),
      ),
    );
    if (_holdMode && enabled) {
      button = Listener(
        onPointerDown: (_) => onHoldStart?.call(),
        onPointerUp: (_) => onHoldEnd?.call(),
        onPointerCancel: (_) => onHoldEnd?.call(),
        child: button,
      );
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled && !_holdMode ? onTap : null,
      child: Tooltip(message: label, child: button),
    );
  }
}

/// Live microphone level as a row of bars, newest on the right.
///
/// Feed it the recent values of `AudioRecorder.level` (0-1, ~20 per second).
class LevelWaveform extends StatelessWidget {
  /// Creates the waveform.
  const LevelWaveform({
    super.key,
    required this.levels,
    this.height = 56,
    this.barCount = 48,
  });

  /// Recent levels, oldest first. Only the last [barCount] are drawn.
  final List<double> levels;

  /// Height in logical pixels.
  final double height;

  /// Number of bars.
  final int barCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Microphone level',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _WaveformPainter(
            levels: levels,
            barCount: barCount,
            color: scheme.primary,
            idleColor: scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.levels,
    required this.barCount,
    required this.color,
    required this.idleColor,
  });

  final List<double> levels;
  final int barCount;
  final Color color;
  final Color idleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / barCount;
    final barWidth = (slot * 0.6).clamp(1.0, 6.0);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    final shown = levels.length > barCount
        ? levels.sublist(levels.length - barCount)
        : levels;
    final empty = barCount - shown.length;
    final mid = size.height / 2;
    for (var i = 0; i < barCount; i++) {
      final hasValue = i >= empty;
      final v = hasValue ? shown[i - empty].clamp(0.0, 1.0) : 0.0;
      final half = (size.height / 2 - barWidth / 2) * v;
      final x = slot * i + slot / 2;
      paint.color = hasValue ? color : idleColor;
      canvas.drawLine(
        Offset(x, mid - half),
        Offset(x, mid + half + 0.01),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.levels != levels || old.color != color || old.idleColor != idleColor;
}

/// Formats [d] as `m:ss` for the recording timer.
String formatElapsed(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
