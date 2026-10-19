import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contracts/navigation.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../home/level_info.dart';
import '../shell/state_views.dart';
import '../theme/theme.dart';
import 'practise_data.dart';

/// Sections of the Practise tab (`/practise?tab=library|sounds|review`).
enum PractiseTab {
  /// Passage library by level.
  library,

  /// Weak sounds; each opens a passage tagged with it.
  sounds,

  /// Words due for review; each opens Fix a word.
  review;

  /// The tab named by a `tab` query value (library when absent or unknown).
  static PractiseTab fromQuery(String? value) => PractiseTab.values.firstWhere(
    (t) => t.name == value,
    orElse: () => PractiseTab.library,
  );
}

/// Practise tab: passage library (locked above current level + 1), weak sounds and
/// words due. Home's weak-sounds and review cards open the matching section.
class PractiseScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const PractiseScreen({super.key, this.initialTab = PractiseTab.library});

  /// Section shown first (and switched to when the route's query changes).
  final PractiseTab initialTab;

  @override
  ConsumerState<PractiseScreen> createState() => _PractiseScreenState();
}

class _PractiseScreenState extends ConsumerState<PractiseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: PractiseTab.values.length,
    vsync: this,
    initialIndex: widget.initialTab.index,
  );

  @override
  void didUpdateWidget(PractiseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _tabs.animateTo(widget.initialTab.index);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(practiseDataProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practise'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Library'),
            Tab(text: 'Weak sounds'),
            Tab(text: 'Words due'),
          ],
        ),
      ),
      body: switch (data) {
        AsyncValue(:final PractiseData value) => TabBarView(
          controller: _tabs,
          children: [
            _Library(data: value),
            _Sounds(sounds: value.sounds),
            _Review(due: value.due),
          ],
        ),
        AsyncValue(error: != null) => MessageView.error(
          onRetry: () => ref.invalidate(practiseDataProvider),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

void _showError(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class _Library extends StatelessWidget {
  const _Library({required this.data});

  final PractiseData data;

  @override
  Widget build(BuildContext context) {
    if (data.passages.isEmpty) {
      return const MessageView(
        icon: Icons.menu_book_outlined,
        title: 'No passages yet',
        message: 'The passage library is empty.',
      );
    }
    final text = Theme.of(context).textTheme;
    final levels = {for (final p in data.passages) p.level}.toList()..sort();
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final level in levels)
          ReadingWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              level == data.level
                                  ? 'Level $level (your level)'
                                  : 'Level $level',
                              style: text.titleMedium,
                            ),
                            Text(
                              '${LevelInfo.length(level)} · '
                              '${LevelInfo.focus(level)}',
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (data.isLocked(level))
                        const Icon(Icons.lock_outline, semanticLabel: 'Locked'),
                    ],
                  ),
                ),
                for (final p in data.passages.where((p) => p.level == level))
                  _PassageTile(
                    passage: p,
                    locked: data.isLocked(level),
                    unlockAt: level - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PassageTile extends StatelessWidget {
  const _PassageTile({
    required this.passage,
    required this.locked,
    required this.unlockAt,
  });

  final Passage passage;
  final bool locked;
  final int unlockAt;

  @override
  Widget build(BuildContext context) {
    final tags = passage.soundTags.isEmpty
        ? '${passage.words.length} words'
        : '${passage.words.length} words · ${passage.soundTags.join('  ')}';
    return ListTile(
      enabled: !locked,
      title: Text(passage.title),
      subtitle: Text(
        locked ? 'Unlocks at level $unlockAt' : tags,
        style: locked ? null : AppTypography.ipa(context, size: 14),
      ),
      trailing: Icon(locked ? Icons.lock_outline : Icons.chevron_right),
      onTap: locked
          ? null
          : () => context.push<Object?>(
              AppRoutes.read,
              extra: ReadArgs(passageId: passage.id),
            ),
    );
  }
}

class _Sounds extends ConsumerWidget {
  const _Sounds({required this.sounds});

  final List<SoundStat> sounds;

  Future<void> _open(BuildContext context, WidgetRef ref, SoundStat s) async {
    try {
      final passage = await ref
          .read(practiceEngineProvider)
          .nextPassage(soundTag: s.ipa);
      if (!context.mounted) return;
      await context.push<Object?>(
        AppRoutes.read,
        extra: ReadArgs(passageId: passage.id),
      );
    } on Object {
      if (context.mounted) {
        _showError(context, 'No passage found for this sound.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sounds.isEmpty) {
      return const MessageView(
        icon: Icons.graphic_eq,
        title: 'No weak sounds yet',
        message:
            'Read a passage and the sounds you find hardest will show here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final s in sounds)
          ReadingWidth(
            child: ListTile(
              leading: SizedBox(
                width: 56,
                child: Text(
                  AppTypography.slashes([s.ipa]),
                  style: AppTypography.ipa(context, size: 20),
                ),
              ),
              title: Text('Practise /${s.ipa}/'),
              subtitle: Text(
                '${s.attempts} ${s.attempts == 1 ? 'time' : 'times'} heard',
              ),
              trailing: ScoreBadge(score: s.accuracy.round(), suffix: '%'),
              onTap: () => _open(context, ref, s),
            ),
          ),
      ],
    );
  }
}

class _Review extends ConsumerWidget {
  const _Review({required this.due});

  final List<ReviewItem> due;

  Future<void> _open(BuildContext context, WidgetRef ref, ReviewItem r) async {
    final target = await reviewTargetFor(
      r,
      progress: ref.read(progressRepositoryProvider),
      content: ref.read(contentRepositoryProvider),
    );
    if (!context.mounted) return;
    if (target == null) {
      _showError(context, 'Read a passage with "${r.word}" to practise it.');
      return;
    }
    await context.push<Object?>(target.path, extra: target.extra);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (due.isEmpty) {
      return const MessageView(
        icon: Icons.event_available_outlined,
        title: 'No words due',
        message: 'Words you miss come back here for review.',
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final r in due)
          ReadingWidth(
            child: ListTile(
              title: Text(r.word),
              subtitle: r.phonemes.isEmpty
                  ? null
                  : Text(
                      AppTypography.slashes(r.phonemes.map((p) => p.ipa)),
                      style: AppTypography.ipa(context, size: 15),
                    ),
              trailing: r.lastScore == null
                  ? const Icon(Icons.chevron_right)
                  : ScoreBadge(score: r.lastScore!),
              onTap: () => _open(context, ref, r),
            ),
          ),
      ],
    );
  }
}
