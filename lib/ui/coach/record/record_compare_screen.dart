import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/audio_recorder.dart';
import '../../../core/contracts/errors.dart';
import '../../../core/contracts/voice_service.dart';
import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../data/coach/coach_store.dart';
import '../../theme/theme.dart';
import 'model_speaker.dart';
import 'pace_stats.dart';
import 'practice_lines.dart';
import 'record_widgets.dart';
import 'rhythm.dart';
import 'shadow_history.dart';

/// Phases of the shadowing (beta) exercise.
enum _Shadow { idle, speaking, listening, scoring }

/// Coach section "Record & compare". The user picks a line (or types one), listens to
/// the British voice at normal or slow speed, then records a reading. The pace and
/// pause readout comes from the recorder's speech segments. Compare sets the reading
/// against an estimate of the model line. Shadowing (beta) has the voice say the line
/// and the user repeat it, then gives a rhythm match against that estimate.
///
/// Recordings are analysed and then deleted: this version cannot play a recording back
/// (see docs/contract-requests/coach-record.md). Nothing is scored for accuracy.
class RecordCompareScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const RecordCompareScreen({super.key});

  @override
  ConsumerState<RecordCompareScreen> createState() =>
      _RecordCompareScreenState();
}

class _RecordCompareScreenState extends ConsumerState<RecordCompareScreen> {
  late final AudioRecorder _recorder;
  late final ModelSpeaker _speaker;
  late final ShadowHistory _history;
  final TextEditingController _line = TextEditingController(
    text: practiceLines.first,
  );

  bool _britishVoice = true;
  PaceStats? _pace;
  String? _recordMessage;

  _Shadow _shadow = _Shadow.idle;
  int _shadowGen = 0;
  double? _rhythm;
  List<int> _recent = const [];
  String? _shadowMessage;
  MicPermission? _shadowBlocked;

  /// The current line, trimmed.
  String get _text => _line.text.trim();

  bool get _busy => _shadow != _Shadow.idle;

  @override
  void initState() {
    super.initState();
    final voice = ref.read(voiceServiceProvider);
    _recorder = ref.read(audioRecorderProvider);
    _speaker = ModelSpeaker(voice);
    _history = ShadowHistory(ref.read(coachStoreProvider));
    unawaited(_loadStartup(voice));
  }

  Future<void> _loadStartup(VoiceService voice) async {
    var british = true;
    try {
      british = await voice.hasBritishVoice();
    } on Object {
      // Assume a voice; speech reports its own failures.
    }
    final recent = await _history.recent();
    if (!mounted) return;
    setState(() {
      _britishVoice = british;
      _recent = recent;
    });
  }

  @override
  void dispose() {
    _shadowGen++;
    _speaker.dispose();
    if (_recorder.isRecording) unawaited(_recorder.cancel());
    _line.dispose();
    super.dispose();
  }

  void _set(VoidCallback change) {
    if (mounted) setState(change);
  }

  /// Changing the line makes earlier readings and scores stale.
  void _lineChanged() {
    unawaited(_speaker.stop());
    _set(() {
      _pace = null;
      _recordMessage = null;
      _rhythm = null;
      _shadowMessage = null;
    });
  }

  void _pick(String? line) {
    if (line == null || _busy) return;
    _line.text = line;
    _lineChanged();
  }

  // Listen and compare.

  Future<void> _listen(String key, double rate) async {
    if (_text.isEmpty || _busy) return;
    await _speaker.toggle(key, _text, rate: rate);
  }

  // Record yourself.

  Future<void> _onRecordStart() => _speaker.stop();

  Future<void> _onClip(AudioClip clip) async {
    final line = _text;
    final regions = speechRegions(await _recorder.speechSegments(clip));
    if (!mounted) return;
    if (regions.isEmpty) {
      _set(() {
        _pace = null;
        _recordMessage = "I didn't hear any speech. Try again a little closer.";
      });
      return;
    }
    _set(() {
      _pace = paceFromRegions(regions, line);
      _recordMessage = null;
    });
  }

  // Shadowing (beta).

  Future<void> _askPermission() async {
    final state = await _recorder.requestPermission();
    _set(() => _shadowBlocked = state == MicPermission.granted ? null : state);
  }

  Future<void> _startShadow() async {
    final line = _text;
    if (line.isEmpty || _busy || _recorder.isRecording) return;
    final gen = ++_shadowGen;
    _set(() {
      _shadow = _Shadow.speaking;
      _rhythm = null;
      _shadowMessage = null;
      _shadowBlocked = null;
    });
    await _speaker.play('shadow', line);
    if (gen != _shadowGen) return;
    try {
      final permission = await _recorder.checkPermission();
      if (gen != _shadowGen) return;
      if (permission != MicPermission.granted) {
        _set(() {
          _shadowBlocked = permission;
          _shadow = _Shadow.idle;
        });
        return;
      }
      await _recorder.start();
    } on MicPermissionException catch (e) {
      _set(() {
        _shadowBlocked = e.state;
        _shadow = _Shadow.idle;
      });
      return;
    } catch (_) {
      _set(() {
        _shadowMessage = "Couldn't start the microphone. Please try again.";
        _shadow = _Shadow.idle;
      });
      return;
    }
    if (gen != _shadowGen) {
      await _recorder.cancel();
      return;
    }
    _set(() => _shadow = _Shadow.listening);
  }

  Future<void> _finishShadow() async {
    if (_shadow != _Shadow.listening) return;
    final line = _text;
    _set(() => _shadow = _Shadow.scoring);
    AudioClip? clip;
    try {
      clip = await _recorder.stop();
      final user = speechRegions(await _recorder.speechSegments(clip));
      if (!mounted) return;
      if (user.isEmpty) {
        _set(
          () => _shadowMessage = "I didn't hear any speech. Try again a little closer to the phone.",
        );
        return;
      }
      final score = rhythmScore(user, estimateReference(line));
      final recent = await _history.add(score);
      _set(() {
        _rhythm = score;
        _recent = recent;
      });
    } catch (_) {
      _set(() => _shadowMessage = "Couldn't score that. Please try again.");
    } finally {
      if (clip != null) unawaited(_recorder.discard(clip));
      _set(() => _shadow = _Shadow.idle);
    }
  }

  Future<void> _stopShadow() async {
    _shadowGen++;
    _set(() => _shadow = _Shadow.idle);
    await _speaker.stop();
    await _recorder.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final line = _text;
    final hasLine = line.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Record & compare')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (!_britishVoice)
            _section('No British voice', [
              const Text(
                'Install an English (UK) voice in your phone\'s system settings '
                'to hear the model line.',
              ),
            ]),
          _section('1. Choose a line', [
            DropdownButton<String>(
              isExpanded: true,
              value: practiceLines.contains(line) ? line : null,
              hint: const Text('Pick a practice sentence'),
              items: [
                for (final l in practiceLines)
                  DropdownMenuItem<String>(
                    value: l,
                    child: Text(l, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _busy ? null : _pick,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _line,
              enabled: !_busy,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Or type your own line',
              ),
              onChanged: (_) => _lineChanged(),
            ),
          ]),
          _section('2. Listen', [
            ValueListenableBuilder<String?>(
              valueListenable: _speaker.playing,
              builder: (context, playing, _) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _speakButton(
                    key: const Key('listenNormal'),
                    id: 'normal',
                    playing: playing,
                    label: 'Listen',
                    rate: VoiceService.normalRate,
                    enabled: hasLine && !_busy,
                  ),
                  _speakButton(
                    key: const Key('listenSlow'),
                    id: 'slow',
                    playing: playing,
                    label: 'Listen slowly',
                    rate: VoiceService.slowRate,
                    enabled: hasLine && !_busy,
                  ),
                ],
              ),
            ),
          ]),
          _section('3. Record yourself', [
            RecordButton(
              recorder: _recorder,
              onStart: _onRecordStart,
              onClip: _onClip,
              enabled: hasLine && !_busy,
            ),
            if (_recordMessage != null) ...[
              const SizedBox(height: 8),
              Text(_recordMessage!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 12),
            if (_pace != null)
              PaceReadout(stats: _pace!, title: 'Your reading')
            else
              const Text('Record a reading to see your pace and pauses.'),
          ]),
          _section('4. Compare', [
            _CompareTable(
              yours: _pace,
              model: hasLine
                  ? paceFromRegions(estimateReference(line), line)
                  : null,
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<String?>(
              valueListenable: _speaker.playing,
              builder: (context, playing, _) => _speakButton(
                key: const Key('compareModel'),
                id: 'compare',
                playing: playing,
                label: 'Hear the model line',
                rate: VoiceService.normalRate,
                enabled: hasLine && !_busy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'The model column is an estimate from the text, not a recording. '
              'Your own recording cannot be played back in this version.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ]),
          _section('5. Shadowing (beta)', [
            const Text(
              'The voice says the line, then you repeat it right after. Tap Done '
              'when you finish. The rhythm match compares your timing with an '
              'estimate of the model, so treat it as a guide.',
            ),
            const SizedBox(height: 12),
            _shadowControls(hasLine),
            if (_shadowBlocked != null) ...[
              const SizedBox(height: 8),
              MicPermissionPrompt(
                state: _shadowBlocked!,
                onAsk: _askPermission,
                onSettings: _recorder.openPermissionSettings,
              ),
            ],
            if (_shadowMessage != null) ...[
              const SizedBox(height: 8),
              Text(_shadowMessage!),
            ],
            if (_rhythm != null) ...[
              const SizedBox(height: 12),
              _RhythmResult(score: _rhythm!),
            ],
            if (_recent.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Recent rhythm estimates: ${_recent.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _shadowControls(bool hasLine) {
    return switch (_shadow) {
      _Shadow.idle => FilledButton.icon(
        key: const Key('shadowStart'),
        onPressed: hasLine ? _startShadow : null,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start shadowing'),
      ),
      _Shadow.speaking => OutlinedButton.icon(
        key: const Key('shadowStop'),
        onPressed: _stopShadow,
        icon: const Icon(Icons.stop),
        label: const Text('Stop'),
      ),
      _Shadow.listening => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            key: const Key('shadowDone'),
            onPressed: _finishShadow,
            icon: const Icon(Icons.check),
            label: const Text('Done'),
          ),
          OutlinedButton.icon(
            key: const Key('shadowStop'),
            onPressed: _stopShadow,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
          ),
        ],
      ),
      _Shadow.scoring => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _speakButton({
    required Key key,
    required String id,
    required String? playing,
    required String label,
    required double rate,
    required bool enabled,
  }) {
    final on = playing == id;
    return OutlinedButton.icon(
      key: key,
      onPressed: enabled ? () => _listen(id, rate) : null,
      icon: Icon(on ? Icons.stop : Icons.volume_up_outlined),
      label: Text(on ? 'Stop' : label),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return ReadingWidth(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Your reading beside the model estimate: speaking time, words per minute and pauses.
class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.yours, required this.model});

  final PaceStats? yours;
  final PaceStats? model;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    String secs(Duration d) =>
        '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';
    String wpm(PaceStats? s) {
      final v = s?.wordsPerMinute;
      return v == null ? '-' : '${v.round()}';
    }

    Widget row(String label, String mine, String estimate) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: text.bodyMedium)),
          Expanded(child: Text(mine, textAlign: TextAlign.end)),
          Expanded(child: Text(estimate, textAlign: TextAlign.end)),
        ],
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            const Expanded(flex: 2, child: SizedBox()),
            Expanded(
              child: Text(
                'Yours',
                textAlign: TextAlign.end,
                style: text.titleSmall,
              ),
            ),
            Expanded(
              child: Text(
                'Model (est.)',
                textAlign: TextAlign.end,
                style: text.titleSmall,
              ),
            ),
          ],
        ),
        row(
          'Speaking time',
          yours == null ? '-' : secs(yours!.speech),
          model == null ? '-' : secs(model!.speech),
        ),
        row('Words per minute', wpm(yours), wpm(model)),
        row(
          'Pauses over 0.4 s',
          yours == null ? '-' : '${yours!.pauseCount}',
          model == null ? '-' : '${model!.pauseCount}',
        ),
      ],
    );
  }
}

/// The shadowing rhythm estimate with a word, an icon and a colour (never colour alone).
class _RhythmResult extends StatelessWidget {
  const _RhythmResult({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final colors = ScoreColors.of(context);
    final text = Theme.of(context).textTheme;
    final (status, color, message) = score >= 80
        ? (WordStatus.good, colors.good, 'Close to the model timing')
        : score >= 60
        ? (WordStatus.close, colors.close, 'Some differences in pace or pauses')
        : (
            WordStatus.fix,
            colors.fix,
            'Quite different. Follow the voice more closely',
          );
    return Row(
      children: [
        Icon(ScoreCue.icon(status), color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Rhythm match ${score.round()} / 100 (estimate): $message',
            style: text.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
