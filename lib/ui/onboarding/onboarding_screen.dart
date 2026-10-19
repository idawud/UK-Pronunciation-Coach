import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/contracts/navigation.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../home/level_info.dart';
import '../shell/state_views.dart';
import '../theme/theme.dart';

/// Reads one placement passage and returns its scored result, or null when the user
/// backed out. The default pushes U2's Read screen with [ReadMode.placement], which
/// pops with the [AttemptResult]. Tests override this provider.
typedef PlacementReader = Future<AttemptResult?> Function(
  BuildContext context,
  Passage passage,
);

/// The [PlacementReader] used by onboarding.
final placementReaderProvider = Provider<PlacementReader>(
  (ref) =>
      (context, passage) => context.push<AttemptResult>(
        AppRoutes.read,
        extra: ReadArgs(passageId: passage.id, mode: ReadMode.placement),
      ),
);

/// Steps of the first-run flow.
enum OnboardingStep {
  /// What the app does and that recordings stay on the phone.
  welcome,

  /// Microphone permission.
  microphone,

  /// British voice check.
  voice,

  /// Placement test: 3 passages (levels 1, 3, 5).
  placement,

  /// Starting level.
  result,
}

/// Sentence spoken by the British voice check.
const String voiceSample = "Hello! Let's practise British English together.";

/// First-run flow: welcome -> microphone -> British voice check -> placement (3
/// passages through the Read route) -> starting level. About 2 minutes. Finishing (or
/// skipping placement) saves `onboardingDone` and opens Home.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [initialStep] is for tests and goldens.
  const OnboardingScreen({
    super.key,
    this.initialStep = OnboardingStep.welcome,
  });

  /// Step shown first.
  final OnboardingStep initialStep;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late OnboardingStep _step = widget.initialStep;

  MicPermission? _mic;
  bool _micBusy = false;

  ({bool hasVoice, String? name})? _voice;

  List<Passage>? _passages;
  bool _passagesFailed = false;
  final List<AttemptResult> _results = [];
  bool _placementBusy = false;
  bool _placementFailed = false;

  int? _level;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _enter(_step);
  }

  void _go(OnboardingStep step) {
    setState(() => _step = step);
    _enter(step);
  }

  void _enter(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.microphone:
        _checkMic();
      case OnboardingStep.voice:
        _checkVoice();
      case OnboardingStep.placement:
        _loadPassages();
      case OnboardingStep.result:
        _loadLevel();
      case OnboardingStep.welcome:
        break;
    }
  }

  Future<void> _checkMic() async {
    setState(() => _mic = null);
    final p = await ref.read(audioRecorderProvider).checkPermission();
    if (mounted) setState(() => _mic = p);
  }

  Future<void> _requestMic() async {
    setState(() => _micBusy = true);
    final p = await ref.read(audioRecorderProvider).requestPermission();
    if (mounted) {
      setState(() {
        _mic = p;
        _micBusy = false;
      });
    }
  }

  Future<void> _checkVoice() async {
    setState(() => _voice = null);
    final voice = ref.read(voiceServiceProvider);
    bool has;
    String? name;
    try {
      has = await voice.hasBritishVoice();
      name = has ? await voice.voiceName() : null;
    } on Object {
      has = false;
    }
    if (mounted) setState(() => _voice = (hasVoice: has, name: name));
  }

  Future<void> _loadPassages() async {
    if (_passages != null) return;
    setState(() => _passagesFailed = false);
    try {
      final p = await ref.read(practiceEngineProvider).placementPassages();
      if (mounted) setState(() => _passages = p);
    } on Object {
      if (mounted) setState(() => _passagesFailed = true);
    }
  }

  Future<void> _readNext() async {
    final passages = _passages!;
    final passage = passages[_results.length];
    setState(() {
      _placementBusy = true;
      _placementFailed = false;
    });
    try {
      final result = await ref.read(placementReaderProvider)(context, passage);
      if (!mounted) return;
      if (result != null) _results.add(result);
      if (_results.length == passages.length) {
        await ref.read(practiceEngineProvider).completePlacement(_results);
        if (!mounted) return;
        setState(() => _placementBusy = false);
        _go(OnboardingStep.result);
        return;
      }
    } on Object {
      if (mounted) setState(() => _placementFailed = true);
    }
    if (mounted) setState(() => _placementBusy = false);
  }

  Future<void> _loadLevel() async {
    setState(() => _level = null);
    int level;
    try {
      level = await ref.read(practiceEngineProvider).currentLevel();
    } on Object {
      level = 1;
    }
    if (mounted) setState(() => _level = level);
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    try {
      final progress = ref.read(progressRepositoryProvider);
      final profile = await progress.profile();
      await progress.saveProfile(profile.copyWith(onboardingDone: true));
      if (mounted) context.go(AppRoutes.home);
    } on Object {
      if (mounted) {
        setState(() => _finishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    }
  }

  OnboardingStep? get _previous => switch (_step) {
    OnboardingStep.microphone => OnboardingStep.welcome,
    OnboardingStep.voice => OnboardingStep.microphone,
    OnboardingStep.placement when _results.isEmpty && !_placementBusy =>
      OnboardingStep.voice,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final previous = _previous;
    final index = _step.index;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: previous == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () => _go(previous),
              ),
        title: Text(
          _step == OnboardingStep.result
              ? 'All set'
              : 'Step ${index + 1} of ${OnboardingStep.values.length - 1}',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (index + 1) / OnboardingStep.values.length,
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: switch (_step) {
          OnboardingStep.welcome => _welcome(context),
          OnboardingStep.microphone => _microphone(context),
          OnboardingStep.voice => _voiceCheck(context),
          OnboardingStep.placement => _placement(context),
          OnboardingStep.result => _result(context),
        },
      ),
    );
  }

  Widget _welcome(BuildContext context) => _StepLayout(
    icon: Icons.record_voice_over_outlined,
    title: 'Speak clear British English',
    body: const [
      'Read short passages aloud. The coach scores every word against Southern '
          'British English and shows you what to fix.',
      'Everything runs on your phone. Your recordings never leave it.',
      'First, a quick set-up and a 2-minute reading test to find your level.',
    ],
    actions: [
      FilledButton(
        onPressed: () => _go(OnboardingStep.microphone),
        child: const Text('Get started'),
      ),
    ],
  );

  Widget _microphone(BuildContext context) {
    final mic = _mic;
    if (mic == null) return const LoadingView();
    final next = OnboardingStep.voice;
    return switch (mic) {
      MicPermission.granted => _StepLayout(
        icon: Icons.mic,
        title: 'Microphone is ready',
        body: const [
          'The coach can hear you read. Recordings stay on your phone.',
        ],
        actions: [
          FilledButton(
            onPressed: () => _go(next),
            child: const Text('Continue'),
          ),
        ],
      ),
      MicPermission.denied => _StepLayout(
        icon: Icons.mic_none,
        title: 'Allow the microphone',
        body: const [
          'The coach needs to hear you read aloud to score your pronunciation.',
          'Recordings are scored on your phone and never uploaded.',
        ],
        actions: [
          FilledButton(
            onPressed: _micBusy ? null : _requestMic,
            child: const Text('Allow microphone'),
          ),
          TextButton(onPressed: () => _go(next), child: const Text('Not now')),
        ],
      ),
      MicPermission.permanentlyDenied => _StepLayout(
        icon: Icons.mic_off_outlined,
        title: 'Microphone is turned off',
        body: const [
          'Microphone access is off for this app. Turn it on in your phone '
              'settings, then come back.',
        ],
        actions: [
          FilledButton(
            onPressed: () =>
                ref.read(audioRecorderProvider).openPermissionSettings(),
            child: const Text('Open settings'),
          ),
          OutlinedButton(
            onPressed: _checkMic,
            child: const Text('Check again'),
          ),
          TextButton(onPressed: () => _go(next), child: const Text('Not now')),
        ],
      ),
    };
  }

  Widget _voiceCheck(BuildContext context) {
    final voice = _voice;
    if (voice == null) return const LoadingView();
    const next = OnboardingStep.placement;
    if (!voice.hasVoice) {
      return _StepLayout(
        icon: Icons.volume_off_outlined,
        title: 'No British voice found',
        body: const [
          'The coach plays words in a British voice. Your phone does not have '
              'an offline English (United Kingdom) voice yet.',
          'Android: Settings > System > Languages > Text-to-speech > install '
              'voice data > English (United Kingdom).',
          'iPhone: Settings > Accessibility > Spoken Content > Voices > '
              'English > English (UK).',
          'You can carry on now and add the voice later.',
        ],
        actions: [
          FilledButton(
            onPressed: () => _go(next),
            child: const Text('Continue'),
          ),
          OutlinedButton(
            onPressed: _checkVoice,
            child: const Text('Check again'),
          ),
        ],
      );
    }
    return _StepLayout(
      icon: Icons.volume_up_outlined,
      title: 'Check the British voice',
      body: [
        'Tap play to hear the voice the coach uses for model answers.',
        if (voice.name != null) 'Voice: ${voice.name}',
      ],
      actions: [
        OutlinedButton.icon(
          onPressed: () => ref.read(voiceServiceProvider).speak(voiceSample),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Play sample'),
        ),
        FilledButton(
          onPressed: () => _go(next),
          child: const Text('Sounds good'),
        ),
      ],
    );
  }

  Widget _placement(BuildContext context) {
    if (_passagesFailed) {
      return MessageView.error(
        message: 'Could not load the reading test.',
        onRetry: _loadPassages,
      );
    }
    final passages = _passages;
    if (passages == null) return const LoadingView();
    final done = _results.length;
    final theme = Theme.of(context);
    return _StepLayout(
      icon: Icons.menu_book_outlined,
      title: 'Find your level',
      body: [
        'Read ${passages.length} short passages aloud. It takes about 2 minutes.',
        if (_placementFailed)
          'Something went wrong. Please try that one again.',
      ],
      extra: Column(
        children: [
          for (var i = 0; i < passages.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: i < done
                  ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                  : CircleAvatar(radius: 14, child: Text('${i + 1}')),
              title: Text(passages[i].title),
              subtitle: Text('Level ${passages[i].level}'),
              trailing: i < done
                  ? ScoreBadge(score: _results[i].overall)
                  : null,
            ),
        ],
      ),
      actions: [
        if (done < passages.length)
          FilledButton.icon(
            onPressed: _placementBusy ? null : _readNext,
            icon: const Icon(Icons.mic_none),
            label: Text('Read passage ${done + 1} of ${passages.length}'),
          )
        else
          const Center(child: CircularProgressIndicator()),
        TextButton(
          onPressed: _placementBusy || _finishing ? null : _finish,
          child: const Text('Skip and start at level 1'),
        ),
      ],
    );
  }

  Widget _result(BuildContext context) {
    final level = _level;
    if (level == null) return const LoadingView();
    return _StepLayout(
      icon: Icons.emoji_events_outlined,
      title: 'You start at level $level',
      body: [
        '${LevelInfo.length(level)}. Focus: ${LevelInfo.focus(level)}.',
        'Read ${LevelInfo.levelUpRun} passages in a row at '
            '${LevelInfo.levelUpScore} or more to move up a level.',
      ],
      actions: [
        FilledButton(
          onPressed: _finishing ? null : _finish,
          child: const Text('Start practising'),
        ),
      ],
    );
  }
}

class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
    this.extra,
  });

  final IconData icon;
  final String title;
  final List<String> body;
  final Widget? extra;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      children: [
        ReadingWidth(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              for (final p in body)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(p, style: theme.textTheme.bodyLarge),
                ),
              if (extra != null) ...[extra!, const SizedBox(height: 12)],
              const SizedBox(height: 12),
              for (final a in actions)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: a),
            ],
          ),
        ),
      ],
    );
  }
}
