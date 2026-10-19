import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contracts/navigation.dart';
import '../../core/models/models.dart';
import 'read_state.dart';
import 'scoring_controller.dart';
import 'widgets/record_controls.dart';

/// Passage text size at `textScale` 1.0.
const double basePassageFontSize = 20;

/// Widest reading column, in logical pixels.
const double maxReadingWidth = 680;

/// Read and record screen (built by the router with [ReadArgs]).
///
/// Passage mode: after scoring it replaces itself with Results. Sentence, word and
/// placement modes: it pops with the scored `AttemptResult` (null if the user leaves
/// first). Callers:
/// `final r = await context.push<AttemptResult>(AppRoutes.read, extra: args)`.
class ReadScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ReadScreen({super.key, required this.args});

  /// What to read and how.
  final ReadArgs args;

  @override
  ConsumerState<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends ConsumerState<ReadScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _left = false;

  ScoringController get _controller =>
      ref.read(scoringControllerProvider(widget.args).notifier);

  @override
  void initState() {
    super.initState();
    // Back from the system settings page: the permission may have changed.
    _lifecycle = AppLifecycleListener(
      onResume: () => _controller.recheckPermission(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onDone(ReadDone done) {
    if (_left || !mounted) return;
    _left = true;
    if (widget.args.mode == ReadMode.passage) {
      context.pushReplacement(
        AppRoutes.results,
        extra: ResultsArgs(result: done.result, levelChange: done.levelChange),
      );
    } else if (GoRouter.maybeOf(context) != null) {
      context.pop(done.result);
    } else {
      Navigator.of(context).pop(done.result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = scoringControllerProvider(widget.args);
    ref.listen(provider, (_, next) {
      if (next.phase case final ReadDone done) _onDone(done);
    });
    final state = ref.watch(provider);
    final content = state.content;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title(content)),
        actions: [
          if (content != null) ...[
            IconButton(
              tooltip: 'Smaller text',
              icon: const Icon(Icons.text_decrease),
              onPressed: state.textScale > minTextScale
                  ? () => _controller.changeTextScale(-textScaleStep)
                  : null,
            ),
            IconButton(
              tooltip: 'Larger text',
              icon: const Icon(Icons.text_increase),
              onPressed: state.textScale < maxTextScale
                  ? () => _controller.changeTextScale(textScaleStep)
                  : null,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 600;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxReadingWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 32 : 16,
                    vertical: wide ? 24 : 12,
                  ),
                  child: ReadBody(state: state, controller: _controller),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _title(ReadContent? content) {
    if (content == null) return 'Read';
    return switch (content.mode) {
      ReadMode.passage || ReadMode.placement => content.passage.title,
      ReadMode.sentence => 'Say the sentence',
      ReadMode.word => 'Say the word',
    };
  }
}

/// The screen body for one [state]. Public so goldens can render fixed states.
class ReadBody extends StatelessWidget {
  /// Creates the body.
  const ReadBody({super.key, required this.state, this.controller});

  /// What to show.
  final ReadState state;

  /// Receives user actions; null renders a static picture (goldens).
  final ScoringController? controller;

  @override
  Widget build(BuildContext context) {
    final content = state.content;
    final phase = state.phase;
    if (phase is ReadLoading || content == null) {
      if (phase case ReadLoadFailed(:final message)) {
        return Center(
          child: _Message(
            icon: Icons.error_outline,
            title: message,
            action: FilledButton.tonal(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Go back'),
            ),
          ),
        );
      }
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading passage'),
      );
    }
    final busy = phase is ReadScoring || phase is ReadDone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(content: content),
        const SizedBox(height: 12),
        Expanded(
          child: Opacity(
            opacity: busy ? 0.55 : 1,
            child: SingleChildScrollView(
              child: _ReadText(content: content, textScale: state.textScale),
            ),
          ),
        ),
        if (state.downloadNotice case final notice?)
          _DownloadNotice(progress: notice, waiting: _waiting(phase)),
        const SizedBox(height: 12),
        _Panel(phase: phase, controller: controller, mode: content.mode),
      ],
    );
  }

  bool _waiting(ReadPhase phase) =>
      phase is ReadScoring && phase.stage == ScoringStage.waitingForDownload;
}

class _Header extends StatelessWidget {
  const _Header({required this.content});

  final ReadContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = 'Level ${content.passage.level}';
    final text = switch (content.mode) {
      ReadMode.passage =>
        content.passageNumber != null
            ? '$level · Passage ${content.passageNumber} of '
                  '${content.passageCount}'
            : level,
      ReadMode.placement => 'Placement test · $level',
      ReadMode.sentence || ReadMode.word => 'From "${content.passage.title}"',
    };
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ReadText extends StatelessWidget {
  const _ReadText({required this.content, required this.textScale});

  final ReadContent content;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = basePassageFontSize * textScale;
    if (content.mode == ReadMode.word) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          content.target.text,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(
            fontSize: size * 2,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Text(
      content.target.text,
      style: theme.textTheme.bodyLarge?.copyWith(fontSize: size, height: 1.6),
    );
  }
}

class _DownloadNotice extends StatelessWidget {
  const _DownloadNotice({required this.progress, required this.waiting});

  final ModelDownloadProgress progress;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (progress.fraction * 100).round();
    final text = progress.state == DownloadState.waitingForWifi
        ? 'The full speech model will download when you are on Wi-Fi.'
        : 'The full speech model is still downloading ($percent%).';
    final detail = waiting
        ? ' Scoring starts when it finishes.'
        : ' Until then, readings use the light model: word scores only.';
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.downloading,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$text$detail',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bottom panel: record button and whatever the phase needs.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.phase,
    required this.controller,
    required this.mode,
  });

  final ReadPhase phase;
  final ScoringController? controller;
  final ReadMode mode;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return switch (phase) {
      ReadLoading() || ReadLoadFailed() => const SizedBox.shrink(),
      ReadIdle() => _RecordPanel(
        button: RecordButton(recording: false, onTap: c?.startRecording),
        caption: mode == ReadMode.word
            ? 'Tap and say the word'
            : 'Tap and read aloud',
      ),
      ReadRecording(:final elapsed, :final levels) => _RecordingPanel(
        elapsed: elapsed,
        levels: levels,
        controller: c,
      ),
      ReadScoring(:final stage, :final progress) => _ScoringPanel(
        stage: stage,
        progress: progress,
        onCancel: stage == ScoringStage.saving ? null : c?.cancelScoring,
      ),
      ReadDone() => const _ScoringPanel(
        stage: ScoringStage.saving,
        progress: 1,
        onCancel: null,
      ),
      ReadPermissionDenied(:final permanently) => _Message(
        icon: Icons.mic_off,
        title: 'Microphone access is off',
        body: permanently
            ? 'Turn on the microphone for this app in your phone settings. '
                  'Your recordings stay on your phone.'
            : 'The app needs the microphone to hear you read. Your recordings '
                  'stay on your phone.',
        action: FilledButton(
          onPressed: c == null
              ? null
              : permanently
              ? c.openPermissionSettings
              : c.requestPermission,
          child: Text(permanently ? 'Open settings' : 'Allow microphone'),
        ),
      ),
      ReadRetryNeeded(:final reason) => _Message(
        icon: switch (reason) {
          RetryReason.tooQuiet => Icons.volume_down,
          RetryReason.tooNoisy => Icons.noise_aware,
          RetryReason.noSpeech => Icons.hearing_disabled,
        },
        title: switch (reason) {
          RetryReason.tooQuiet => 'That was too quiet',
          RetryReason.tooNoisy => "It's too noisy here",
          RetryReason.noSpeech => "We didn't hear you",
        },
        body: switch (reason) {
          RetryReason.tooQuiet =>
            'Speak up a little or hold the phone closer, then try again.',
          RetryReason.tooNoisy =>
            'Background noise makes scores unfair. Find a quieter spot and '
                'try again.',
          RetryReason.noSpeech =>
            'Check that nothing covers the microphone and read aloud.',
        },
        action: FilledButton.icon(
          onPressed: c?.startRecording,
          icon: const Icon(Icons.mic),
          label: const Text('Try again'),
        ),
      ),
      ReadFailed(:final message) => _Message(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        body: message,
        action: FilledButton(
          onPressed: c?.reset,
          child: const Text('Try again'),
        ),
      ),
    };
  }
}

class _RecordPanel extends StatelessWidget {
  const _RecordPanel({required this.button, required this.caption});

  final Widget button;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 8),
        Text(caption, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _RecordingPanel extends StatelessWidget {
  const _RecordingPanel({
    required this.elapsed,
    required this.levels,
    required this.controller,
  });

  final Duration elapsed;
  final List<double> levels;
  final ScoringController? controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LevelWaveform(levels: levels),
        const SizedBox(height: 4),
        Text(
          formatElapsed(elapsed),
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        RecordButton(recording: true, onTap: controller?.stopRecording),
        const SizedBox(height: 8),
        Text('Tap to stop', style: theme.textTheme.bodyMedium),
        Text(
          'Stops by itself after 2 s of silence',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: controller?.discardRecording,
          child: const Text('Discard'),
        ),
      ],
    );
  }
}

class _ScoringPanel extends StatelessWidget {
  const _ScoringPanel({
    required this.stage,
    required this.progress,
    required this.onCancel,
  });

  final ScoringStage stage;
  final double progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = switch (stage) {
      ScoringStage.checkingAudio => 'Checking the recording',
      ScoringStage.preparingModel => 'Loading the speech model',
      ScoringStage.waitingForDownload =>
        'Waiting for the speech model download',
      ScoringStage.recognising => 'Listening to your sounds',
      ScoringStage.scoring => 'Comparing with British English',
      ScoringStage.saving => 'Saving your result',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Scoring...',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: progress,
          semanticsLabel: 'Scoring progress',
          semanticsValue: '${(progress * 100).round()}%',
        ),
        const SizedBox(height: 4),
        Align(
          child: TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.body,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        if (body case final body?) ...[
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 12),
        action,
      ],
    );
  }
}
