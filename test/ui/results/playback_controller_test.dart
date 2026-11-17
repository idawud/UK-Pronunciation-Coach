import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/contracts/contracts.dart';
import 'package:uk_pronunciation_coach/ui/results/playback_controller.dart';
import 'package:uk_pronunciation_coach/ui/results/speech_segments.dart';

import 'blocking_voice.dart';

/// Lets queued microtasks run so the player reaches its next `speak`.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

const _a = SpeechSegment('alpha', VoiceService.normalRate);
const _b = SpeechSegment('beta', VoiceService.slowRate);
const _c = SpeechSegment('gamma', VoiceService.normalRate);

void main() {
  late BlockingVoice voice;
  late SegmentPlayer player;

  setUp(() {
    voice = BlockingVoice();
    player = SegmentPlayer(voice);
  });

  tearDown(() => player.dispose());

  test('plays segments one after another in order', () async {
    final done = player.play(PlaybackKind.stressed, [_a, _b, _c]);
    await _settle();
    expect(player.active, PlaybackKind.stressed);
    expect(voice.spoken, [('alpha', 1.0)]);

    voice.finishNext();
    await _settle();
    expect(voice.spoken, [('alpha', 1.0), ('beta', 0.6)]);

    voice.finishNext();
    await _settle();
    expect(voice.spoken.last, ('gamma', 1.0));

    voice.finishNext();
    await done;
    expect(player.active, isNull);
    expect(voice.spoken.length, 3);
    expect(voice.stopCount, 0);
  });

  test('stop mid-sequence ends playback and speaks nothing more', () async {
    final done = player.play(PlaybackKind.sentence, [_a, _b, _c]);
    await _settle();
    voice.finishNext();
    await _settle();
    expect(voice.spoken.length, 2);

    await player.stop();
    await done;
    expect(player.active, isNull);
    expect(voice.stopCount, 1);
    expect(voice.spoken.length, 2);
    expect(voice.pendingCount, 0);
  });

  test('tapping the active kind again stops', () async {
    unawaited(player.play(PlaybackKind.sentence, [_a, _b]));
    await _settle();
    await player.play(PlaybackKind.sentence, [_a, _b]);
    expect(player.active, isNull);
    expect(voice.stopCount, 1);
    expect(voice.spoken.length, 1);
  });

  test('switching kind stops the old sequence and plays the new one', () async {
    final first = player.play(PlaybackKind.sentence, [_a, _b]);
    await _settle();
    final second = player.play(PlaybackKind.wrongWords, [_c]);
    await _settle();
    expect(player.active, PlaybackKind.wrongWords);
    expect(voice.spoken.last, ('gamma', 1.0));

    // The superseded sequence wakes up and must not speak its next segment.
    voice.finishNext();
    await first;
    await _settle();
    expect(voice.spoken.map((s) => s.$1), ['alpha', 'gamma']);
    expect(player.active, PlaybackKind.wrongWords);

    voice.finishNext();
    await second;
    expect(player.active, isNull);
  });

  test('dispose stops speech and does not notify afterwards', () async {
    var notifications = 0;
    player.addListener(() => notifications++);
    unawaited(player.play(PlaybackKind.sentence, [_a]));
    await _settle();
    final before = notifications;

    player.dispose();
    expect(voice.stopCount, 1);
    expect(voice.pendingCount, 0);
    expect(notifications, before);
    // Prevent the tearDown from disposing twice.
    player = SegmentPlayer(voice);
  });

  test('a speech error resets the player to idle', () async {
    final throwing = SegmentPlayer(ThrowingVoice());
    addTearDown(throwing.dispose);
    await throwing.play(PlaybackKind.stressed, [_a, _b]);
    expect(throwing.active, isNull);
  });

  test('empty segments leave the player idle', () async {
    await player.play(PlaybackKind.wrongWords, const []);
    expect(player.active, isNull);
    expect(voice.spoken, isEmpty);
  });
}
