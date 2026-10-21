// The end-to-end journey (I1-integration), shared by the on-device test
// (integration_test/e2e/journey_test.dart) and its host mirror
// (test/e2e/journey_host_test.dart): first run -> onboarding -> placement -> Home ->
// Read -> Results -> Fix a word -> level up after 3 high scores -> Progress shows
// history -> delete all data, with fixture audio played into A1's real recorder and
// no network.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/providers.dart';
import 'package:uk_pronunciation_coach/engine/audio/audio.dart';
import 'package:uk_pronunciation_coach/ui/read/read_screen.dart';

/// Fixture clips the journey reads (16 kHz mono WAV bytes), by role.
class JourneyClips {
  /// Creates the set.
  const JourneyClips({required this.offScript, required this.goodReads});

  /// Speech that matches no passage ("On Thursday we walked by the river."):
  /// placement reads and the first passage, so it scores low with red words.
  final Uint8List offScript;

  /// Clean British reads of library passages, by passage id; each must score 85+.
  final Map<String, Uint8List> goodReads;
}

/// [MicSource] that plays whichever clip the journey chose for the next
/// recording, followed by digital silence so `silenceDetected` stops it.
class JourneyMic implements MicSource {
  /// Creates the mic. [realTime] paces 20 ms blocks like a phone; otherwise the
  /// clip and 2.5 s of silence arrive at once (host tests under fake time).
  JourneyMic({this.realTime = true});

  /// Pace the audio in real time.
  final bool realTime;

  /// WAV bytes for the next [start].
  Uint8List? next;

  /// Number of recordings started.
  int starts = 0;

  StreamController<Uint8List>? _controller;
  Timer? _timer;

  static const _blockBytes = 640; // 20 ms at 16 kHz, 16-bit
  static const _tailBytes = 2500 * 32; // 2.5 s of silence

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async {
    final wav = next;
    if (wav == null) throw StateError('JourneyMic: no clip chosen');
    if (_controller != null) throw StateError('Already started');
    starts++;
    final audio = decodeWav(wav);
    final pcm = encodeWav(audio.samples, sampleRate: sampleRate).sublist(44);
    final controller = _controller = StreamController<Uint8List>();
    if (realTime) {
      var offset = 0;
      _timer = Timer.periodic(const Duration(milliseconds: 20), (_) {
        if (controller.isClosed) return;
        if (offset < pcm.length) {
          final end = offset + _blockBytes < pcm.length
              ? offset + _blockBytes
              : pcm.length;
          controller.add(Uint8List.sublistView(pcm, offset, end));
          offset = end;
        } else {
          controller.add(Uint8List(_blockBytes));
        }
      });
    } else {
      Timer.run(() {
        if (controller.isClosed) return;
        controller
          ..add(Uint8List.fromList(pcm))
          ..add(Uint8List(_tailBytes));
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
  Future<void> dispose() => stop();
}

/// Records every HTTP client and socket the app opens while installed.
class NetworkSpy {
  /// HTTP clients created.
  final List<String> httpClients = [];

  /// Socket connections attempted (host:port).
  final List<String> sockets = [];

  HttpOverrides? _previousHttp;
  IOOverrides? _previousIo;

  /// Starts recording; every connection attempt also fails.
  void install() {
    _previousHttp = HttpOverrides.current;
    _previousIo = IOOverrides.current;
    HttpOverrides.global = _NoHttp(this);
    IOOverrides.global = _NoSockets(this);
  }

  /// Stops recording.
  void uninstall() {
    HttpOverrides.global = _previousHttp;
    IOOverrides.global = _previousIo;
  }
}

class _NoHttp extends HttpOverrides {
  _NoHttp(this.spy);
  final NetworkSpy spy;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    spy.httpClients.add(
      StackTrace.current.toString().split('\n').take(6).join(' | '),
    );
    return super.createHttpClient(context);
  }
}

final class _NoSockets extends IOOverrides {
  _NoSockets(this.spy);
  final NetworkSpy spy;

  @override
  Future<Socket> socketConnect(
    dynamic host,
    int port, {
    dynamic sourceAddress,
    int sourcePort = 0,
    Duration? timeout,
  }) {
    spy.sockets.add('$host:$port');
    return Future.error(const SocketException('e2e: network is off'));
  }

  @override
  Future<ConnectionTask<Socket>> socketStartConnect(
    dynamic host,
    int port, {
    dynamic sourceAddress,
    int sourcePort = 0,
  }) {
    spy.sockets.add('$host:$port');
    return Future.error(const SocketException('e2e: network is off'));
  }
}

/// Drives the app through the journey.
class Journey {
  /// Creates the driver. [idle] lets real asynchronous work (isolates, files,
  /// the database) run between frames: `tester.runAsync` on the host, a short real
  /// delay on a device.
  Journey(
    this.tester, {
    required this.mic,
    required this.clips,
    required this.idle,
    this.timeout = const Duration(seconds: 90),
  });

  /// The tester.
  final WidgetTester tester;

  /// The microphone feeding A1's recorder.
  final JourneyMic mic;

  /// The audio to read.
  final JourneyClips clips;

  /// Lets real asynchronous work run.
  final Future<void> Function() idle;

  /// Longest wait for one step.
  final Duration timeout;

  /// The app's provider container.
  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

  /// Pumps frames (and lets real work run) until [finder] matches.
  Future<void> waitFor(Finder finder, {String? reason}) async {
    final watch = Stopwatch()..start();
    while (true) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) return;
      if (watch.elapsed > timeout) {
        fail(
          'Timed out waiting for ${reason ?? finder}. On screen: ${_onScreen()}',
        );
      }
      await idle();
    }
  }

  /// The texts on screen, for failure messages.
  String _onScreen() => [
    for (final e in find.byType(Text).evaluate())
      (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText(),
  ].whereType<String>().where((t) => t.isNotEmpty).join(' | ');

  /// Pumps frames for about [frames] x 50 ms of fake time while real work runs.
  Future<void> settle({int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await idle();
    }
  }

  /// Waits for [text], then taps it.
  Future<void> tapText(String text) async {
    final f = find.text(text);
    await waitFor(f, reason: '"$text"');
    await tester.ensureVisible(f.first);
    await tester.pump();
    await tester.tap(f.first);
    await tester.pump();
  }

  /// Taps the bottom navigation (or rail) destination [label].
  Future<void> tapTab(String label) async {
    final inBar = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is NavigationBar || w is NavigationRail,
      ),
      matching: find.text(label),
    );
    await waitFor(inBar, reason: 'tab $label');
    await tester.tap(inBar.first);
    // The router's onboarding check reads the profile from the database.
    await settle();
  }

  /// On the Read screen: plays [clip] into the recorder and waits until the
  /// recording has stopped by itself (2 s of silence) and been scored.
  Future<void> readAloud(Uint8List clip, {required Finder thenShows}) async {
    final start = find.bySemanticsLabel('Start recording');
    await waitFor(start, reason: 'record button');
    mic.next = clip;
    await tester.tap(start);
    await tester.pump();
    await waitFor(thenShows, reason: 'after reading: $thenShows');
  }

  /// The passage id the Read screen shows.
  String get readingPassageId =>
      tester.widget<ReadScreen>(find.byType(ReadScreen)).args.passageId;

  /// Runs the whole journey.
  Future<void> run() async {
    final spy = NetworkSpy()..install();
    try {
      await _run();
    } finally {
      spy.uninstall();
    }
    expect(spy.httpClients, isEmpty, reason: 'no HTTP outside the download');
    expect(spy.sockets, isEmpty, reason: 'no sockets outside the download');
  }

  Future<void> _run() async {
    // 1. First run: onboarding.
    await tapText('Get started');
    await tapText(
      'Continue',
    ); // microphone already allowed (fixture permissions)
    // British voice: present ("Sounds good") or missing ("Continue").
    await waitFor(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data == 'Sounds good' || w.data == 'No British voice found'),
      ),
      reason: 'voice step',
    );
    await tapText(
      find.text('Sounds good').evaluate().isNotEmpty
          ? 'Sounds good'
          : 'Continue',
    );

    // 2. Placement: three passages read off-script, so the user starts at level 1.
    await waitFor(find.text('Find your level'));
    for (var i = 1; i <= 3; i++) {
      await tapText('Read passage $i of 3');
      await readAloud(
        clips.offScript,
        thenShows: i < 3
            ? find.text('Read passage ${i + 1} of 3')
            : find.text('You start at level 1'),
      );
    }
    await tapText('Start practising');

    // 3. Home -> today's passage -> Read -> Results (off-script: red words).
    await tapText("Start today's passage");
    await waitFor(find.byType(ReadScreen));
    final firstPassage = readingPassageId;
    final fixButton = find.textContaining(RegExp(r'^Fix \d+ red words?$'));
    await readAloud(clips.offScript, thenShows: fixButton);
    expect(find.text('Results'), findsOneWidget);
    final progress = container.read(progressRepositoryProvider);
    final first = (await _later(progress.attempts())).single;
    expect(first.passageId, firstPassage);
    expect(first.redWords, isNotEmpty);
    expect(first.audioPath, isNull, reason: 'recordings are not kept');

    // 4. Fix a word: hold to say the first red word, then skip to the end.
    await tester.tap(fixButton.first);
    await tester.pump();
    await waitFor(find.text('Fix a word'));
    final hold = find.byIcon(Icons.mic_none);
    await waitFor(hold, reason: 'hold-to-record');
    await tester.ensureVisible(hold.first);
    await tester.pump();
    mic.next = clips.offScript;
    final gesture = await tester.startGesture(tester.getCenter(hold.first));
    await waitFor(
      find.text("Release when you've finished"),
      reason: 'word recording',
    );
    await settle(frames: 20);
    await gesture.up();
    await waitFor(find.textContaining('Last score'), reason: 'word scored');
    final summary = find.textContaining(RegExp(r'^Fixed \d+ of \d+ words?$'));
    for (var i = 0; i < 80 && summary.evaluate().isEmpty; i++) {
      // A word at 80+ offers "Next", otherwise "Skip" (also on the sentence step).
      final next = find.text('Next');
      final skip = find.text('Skip');
      await waitFor(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data == 'Next' ||
                  w.data == 'Skip' ||
                  (w.data ?? '').startsWith('Fixed ')),
        ),
        reason: 'Next, Skip or the summary',
      );
      final step = next.evaluate().isNotEmpty ? next : skip;
      if (step.evaluate().isEmpty) continue;
      await tester.ensureVisible(step.first);
      await tester.pump();
      await tester.tap(step.first);
      // Moving on saves the word's last try (real database): let it finish.
      await settle();
    }
    final back = find.widgetWithText(FilledButton, 'Back to results');
    await _scrollTo(back);
    await tester.tap(back);
    await tester.pump();
    await waitFor(find.text('Next passage'), reason: 'back on Results');
    await tester.pageBack();
    await tester.pump();

    // 5. Three clean reads from the Library at 85+ -> level up.
    final good = clips.goodReads.entries.toList();
    expect(good, hasLength(greaterThanOrEqualTo(3)));
    for (var i = 0; i < 3; i++) {
      await tapTab('Practise');
      final passage = await _later(
        container.read(contentRepositoryProvider).byId(good[i].key),
      );
      final tile = find.text(passage.title);
      await _scrollTo(tile);
      await tester.tap(tile);
      await tester.pump();
      await waitFor(find.byType(ReadScreen));
      expect(readingPassageId, passage.id);
      await readAloud(good[i].value, thenShows: find.text('Next passage'));
      final latest = (await _later(progress.attempts(limit: 1))).single;
      expect(
        latest.overall,
        greaterThanOrEqualTo(85),
        reason: '${passage.id} must read at 85+ for the level-up run',
      );
      if (i == 2) {
        await waitFor(find.text('Level up: level 2'), reason: 'level up card');
      }
      await tester.pageBack();
      await tester.pump();
    }
    expect((await _later(progress.profile())).level, 2);

    // 6. Progress shows the history.
    await tapTab('Progress');
    await waitFor(find.text('Score trend'));
    await _scrollTo(find.text('Level 1 to 2'));
    expect(await _later(progress.attempts()), hasLength(4));

    // 7. Settings -> delete all data -> back to first run.
    await tapTab('Settings');
    await waitFor(find.text('Daily goal'), reason: 'Settings');
    await _scrollTo(find.text('Delete all data'));
    await tester.tap(find.text('Delete all data'));
    await tester.pump();
    await tapText('Delete everything');
    await settle(frames: 20);
    expect(await _later(progress.attempts()), isEmpty);
    expect((await _later(progress.profile())).onboardingDone, isFalse);
    await tapTab('Home');
    await waitFor(find.text('Get started'), reason: 'onboarding again');
  }

  /// Awaits [future] while pumping, so work started under fake time completes.
  Future<T> _later<T>(Future<T> future) async {
    T? value;
    Object? error;
    var done = false;
    unawaited(
      future.then(
        (v) {
          value = v;
          done = true;
        },
        onError: (Object e) {
          error = e;
          done = true;
        },
      ),
    );
    final watch = Stopwatch()..start();
    while (!done) {
      if (watch.elapsed > timeout) fail('Timed out waiting for a result');
      await tester.pump(const Duration(milliseconds: 10));
      await idle();
    }
    if (error != null) throw error!;
    return value as T;
  }

  /// Scrolls the first vertical scrollable on screen until [finder] is built.
  Future<void> _scrollTo(Finder finder) async {
    final vertical = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    for (var i = 0; i < 80 && finder.evaluate().isEmpty; i++) {
      if (vertical.evaluate().isEmpty) {
        await tester.pump(const Duration(milliseconds: 50));
        await idle();
        continue;
      }
      await tester.drag(vertical.first, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets, reason: 'On screen: ${_onScreen()}');
    await tester.ensureVisible(finder.first);
    await tester.pump();
  }
}
