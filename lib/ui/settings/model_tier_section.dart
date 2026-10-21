import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/contracts/errors.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import 'settings_providers.dart';

/// Model tier choice and the optional full-model download: size, progress, cancel,
/// Wi-Fi only, retry and delete.
class ModelTierSection extends ConsumerStatefulWidget {
  /// Creates the section for [profile].
  const ModelTierSection({super.key, required this.profile});

  /// Current profile (for `tierOverride`).
  final UserProfile profile;

  @override
  ConsumerState<ModelTierSection> createState() => _ModelTierSectionState();
}

/// The three tier choices: automatic (recommended), light, full.
enum TierChoice {
  /// Full once it is downloaded, else light (`preferredTier` in core/providers).
  auto,

  /// Always light.
  light,

  /// Always full.
  full,
}

class _ModelTierSectionState extends ConsumerState<ModelTierSection> {
  bool _wifiOnly = true;

  TierChoice get _choice => switch (widget.profile.tierOverride) {
    null => TierChoice.auto,
    ModelTier.light => TierChoice.light,
    ModelTier.full => TierChoice.full,
  };

  Future<void> _setTier(TierChoice choice) async {
    final repo = ref.read(progressRepositoryProvider);
    final profile = await repo.profile();
    await repo.saveProfile(
      profile.copyWith(
        tierOverride: switch (choice) {
          TierChoice.auto => null,
          TierChoice.light => ModelTier.light,
          TierChoice.full => ModelTier.full,
        },
      ),
    );
  }

  Future<void> _download() async {
    try {
      await ref
          .read(phonemeRecognizerProvider)
          .downloadFullModel(requireWifi: _wifiOnly);
    } on ModelDownloadException {
      // The state (failed / cancelled) is shown from the progress stream.
    }
    if (mounted) ref.invalidate(fullTierAvailableProvider);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete the full model?'),
        content: const Text(
          'Scoring goes back to the light model, with word scores only. You '
          'can download the full model again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(phonemeRecognizerProvider).deleteFullModel();
    ref.invalidate(fullTierAvailableProvider);
    if (widget.profile.tierOverride == ModelTier.full) {
      await _setTier(TierChoice.auto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recognizer = ref.watch(phonemeRecognizerProvider);
    final progress =
        ref.watch(modelDownloadProvider).value ?? recognizer.downloadStatus;
    final fullAvailable = ref.watch(fullTierAvailableProvider).value ?? false;
    final recommended = ref.watch(recommendedTierProvider).value;
    final t = Theme.of(context).textTheme;
    final size = formatMegabytes(
      progress.totalBytes > 0
          ? progress.totalBytes
          : recognizer.fullModelSizeBytes,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Light is built in and gives word scores. Full adds a score for '
            'every sound and needs a one-time $size download. Auto uses Full '
            'once it is downloaded.',
            style: t.bodyMedium,
          ),
          if (recommended != null) ...[
            const SizedBox(height: 4),
            Text(
              'Recommended for this phone: ${_tierName(recommended)}.',
              style: t.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          SegmentedButton<TierChoice>(
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(value: TierChoice.auto, label: Text('Auto')),
              const ButtonSegment(
                value: TierChoice.light,
                label: Text('Light'),
              ),
              ButtonSegment(
                value: TierChoice.full,
                label: const Text('Full'),
                enabled: fullAvailable,
                tooltip: fullAvailable ? null : 'Download the full model first',
              ),
            ],
            selected: {_choice},
            onSelectionChanged: (s) => _setTier(s.single),
          ),
          const SizedBox(height: 12),
          _DownloadStatus(
            progress: progress,
            fullAvailable: fullAvailable,
            size: size,
            wifiOnly: _wifiOnly,
            onWifiOnly: (v) => setState(() => _wifiOnly = v),
            onDownload: _download,
            onCancel: recognizer.cancelDownload,
            onDelete: _delete,
          ),
        ],
      ),
    );
  }
}

String _tierName(ModelTier tier) => switch (tier) {
  ModelTier.light => 'Light',
  ModelTier.full => 'Full',
};

class _DownloadStatus extends StatelessWidget {
  const _DownloadStatus({
    required this.progress,
    required this.fullAvailable,
    required this.size,
    required this.wifiOnly,
    required this.onWifiOnly,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
  });

  final ModelDownloadProgress progress;
  final bool fullAvailable;
  final String size;
  final bool wifiOnly;
  final ValueChanged<bool> onWifiOnly;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final received = formatMegabytes(progress.receivedBytes);

    if (fullAvailable || progress.state == DownloadState.completed) {
      return Row(
        children: [
          Icon(Icons.check_circle_outline, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('Full model on this phone ($size)')),
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      );
    }

    if (progress.isActive) {
      final (label, value) = switch (progress.state) {
        DownloadState.waitingForWifi => ('Waiting for Wi-Fi…', null),
        DownloadState.verifying => ('Checking the download…', null),
        _ => (
          'Downloading: $received of $size '
              '(${(progress.fraction * 100).round()}%)',
          progress.fraction,
        ),
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.bodyMedium),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: value),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ),
        ],
      );
    }

    final failed = progress.state == DownloadState.failed;
    final paused =
        progress.state == DownloadState.cancelled && progress.receivedBytes > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (failed)
          Row(
            children: [
              Icon(Icons.error_outline, color: scheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'The download failed'
                  '${progress.error == null ? '' : ': ${progress.error}'}. '
                  'Try again; it carries on where it stopped.',
                  style: t.bodyMedium?.copyWith(color: scheme.error),
                ),
              ),
            ],
          ),
        if (paused) Text('Paused at $received of $size.', style: t.bodyMedium),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Download on Wi-Fi only'),
          value: wifiOnly,
          onChanged: onWifiOnly,
        ),
        FilledButton.tonalIcon(
          onPressed: onDownload,
          icon: const Icon(Icons.download),
          label: Text(
            failed
                ? 'Try again'
                : paused
                ? 'Resume download'
                : 'Download full model ($size)',
          ),
        ),
      ],
    );
  }
}
