// Tests for the I2-eval Dart harness (tools/eval/dart/), using canned posteriors.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

import '../../../tools/eval/dart/eval_harness.dart';
import '../../../tools/eval/dart/host_ort.dart';

const vocab = ['<pad>', '<s>', '</s>', '<unk>', 'k', 'æ', 't', 'd', 'ɒ', 'g'];

/// Peaky CTC posteriors for [phones] (each 2 frames, blanks between).
PhonemePosteriors posteriorsFor(List<String> phones) {
  final frames = <Float32List>[];
  Float32List frame(int hot) {
    final f = Float32List(vocab.length);
    for (var i = 0; i < f.length; i++) {
      f[i] = math.log(i == hot ? 0.9 : 0.1 / (vocab.length - 1));
    }
    return f;
  }

  for (var i = 0; i < 4; i++) {
    frames.add(frame(0));
  }
  for (final p in phones) {
    frames
      ..add(frame(vocab.indexOf(p)))
      ..add(frame(vocab.indexOf(p)))
      ..add(frame(0));
  }
  for (var i = 0; i < 4; i++) {
    frames.add(frame(0));
  }
  return PhonemePosteriors(vocab: vocab, frames: frames);
}

Passage passage(String id, List<(String, List<String>)> words) {
  var offset = 0;
  final specs = <WordSpec>[];
  for (var i = 0; i < words.length; i++) {
    final (text, ph) = words[i];
    specs.add(
      WordSpec(
        text: text,
        index: i,
        offset: offset,
        scorable: ph.isNotEmpty,
        phonemes: [
          for (final p in ph) PhonemeSpec(ipa: p, stress: p == 'æ' ? 1 : 0),
        ],
      ),
    );
    offset += text.length + 1;
  }
  return Passage(
    id: id,
    level: 1,
    title: id,
    text: words.map((w) => w.$1).join(' '),
    words: specs,
  );
}

Uint8List wav(int samples, {int rate = 16000}) {
  final b = BytesBuilder();
  void u32(int v) =>
      b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) =>
      b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  b.add(ascii.encode('RIFF'));
  u32(36 + 2 * samples + 10);
  b.add(ascii.encode('WAVE'));
  b.add(ascii.encode('LIST'));
  u32(1); // odd-sized chunk, padded
  b.add([0, 0]);
  b.add(ascii.encode('fmt '));
  u32(16);
  u16(1);
  u16(1);
  u32(rate);
  u32(rate * 2);
  u16(2);
  u16(16);
  b.add(ascii.encode('data'));
  u32(2 * samples);
  b.add(Uint8List(2 * samples));
  return b.toBytes();
}

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('i2_harness'));
  tearDown(() => tmp.delete(recursive: true));

  test('parseManifest reads columns and resolves paths', () {
    const tsv =
        'item\twav\tpassage\tspeaker\tsplit\tkind\ttarget\tprobe\n'
        'a\twav/a.wav\tpa\tp1\ttune\tnative\t\t\n'
        'a.sub\t/abs/a.wav\tpa.sub\tp1\ttune\tsub\t2\tcat:æ->ɛ\n'
        '\n';
    final items = parseManifest(tsv, dataDir: '/data');
    expect(items, hasLength(2));
    expect(items[0].wav, '/data/wav/a.wav');
    expect(items[0].kind, 'native');
    expect(items[0].target, isNull);
    expect(items[1].wav, '/abs/a.wav');
    expect(items[1].target, 2);
    expect(items[1].probe, 'cat:æ->ɛ');
    final minimal = parseManifest('item\twav\tpassage\nx\tx.wav\tpx\n');
    expect(minimal.single.kind, 'native');
    expect(minimal.single.speaker, '');
    expect(parseManifest(''), isEmpty);
    expect(() => parseManifest('item\twav\n'), throwsFormatException);
  });

  test('parsePassages and wavDuration', () {
    final p = passage('pa', [
      ('cat', ['k', 'æ', 't']),
    ]);
    final map = parsePassages(jsonEncode([p.toJson()]));
    expect(map['pa'], p);
    expect(wavDuration(wav(8000)).inMilliseconds, 500);
    expect(
      () => wavDuration(Uint8List.fromList(ascii.encode('RIFF0000WAVE'))),
      throwsFormatException,
    );
  });

  test('csv quoting', () {
    expect(csvField('a,b'), '"a,b"');
    expect(csvField('say "hi"'), '"say ""hi"""');
    expect(csvField(null), '');
    expect(csvLine([1, 'x', null]), '1,x,');
  });

  test('PosteriorCache round-trips and wraps a source', () async {
    final w = File('${tmp.path}/a.wav')..writeAsBytesSync(wav(1600));
    final cache = PosteriorCache(Directory('${tmp.path}/cache'), 'm1');
    expect(cache.read(w.path), isNull);
    final post = posteriorsFor(['k', 'æ', 't']);
    var calls = 0;
    final source = cache.wrap((path) async {
      calls++;
      return TimedPosteriors(post, modelMs: 5, totalMs: 6);
    });
    final first = await source(w.path);
    expect(first.modelMs, 5);
    final second = await source(w.path);
    expect(calls, 1);
    expect(second.modelMs, isNull);
    expect(second.posteriors.vocab, vocab);
    expect(second.posteriors.frames.length, post.frames.length);
    expect(second.posteriors.frames[5], post.frames[5]);
    expect(second.posteriors.tier, post.tier);
    // Another model id misses.
    expect(
      PosteriorCache(Directory('${tmp.path}/cache'), 'm2').read(w.path),
      isNull,
    );
  });

  test('runEval scores natives and probes with every config', () async {
    final w = File('${tmp.path}/a.wav')..writeAsBytesSync(wav(16000));
    final native = passage('pa', [
      ('cat', ['k', 'æ', 't']),
      ('dog', ['d', 'ɒ', 'g']),
      ('Zork', []),
    ]);
    final swapped = passage('pa.swap', [
      ('cat', ['k', 'æ', 't']),
      ('tot', ['t', 'ɒ', 't']),
      ('Zork', []),
    ]);
    final items = [
      EvalItem(item: 'pa', wav: w.path, passage: 'pa', speaker: 'p1'),
      EvalItem(
        item: 'pa.swap',
        wav: w.path,
        passage: 'pa.swap',
        kind: 'swap',
        target: 1,
        probe: 'dog->tot',
      ),
    ];
    var calls = 0;
    final logs = <String>[];
    final out = await runEval(
      items: items,
      passages: {native.id: native, swapped.id: swapped},
      source: (path) async {
        calls++;
        return TimedPosteriors(
          posteriorsFor(['k', 'æ', 't', 'd', 'ɒ', 'g']),
          modelMs: 10,
          totalMs: 12,
        );
      },
      configs: {
        'default': const ScoringConfig(),
        'strict': const ScoringConfig(goodThreshold: 101, closeThreshold: 101),
      },
      log: logs.add,
    );
    expect(calls, 1, reason: 'one recognise per WAV');
    expect(logs, hasLength(1));
    final words = out.words['default']!;
    expect(words.first, wordCsvHeader.join(','));
    expect(words, hasLength(1 + 6));
    final rows = [for (final l in words.skip(1)) l.split(',')];
    expect(rows[0][7], 'cat');
    expect(rows[0][9], 'good');
    expect(rows[0][11], 'k æ t');
    expect(rows[0][12], '0 1 0');
    expect(rows[2][9], 'notScored');
    final target = rows[4];
    expect(target[1], 'pa.swap');
    expect(target[8], '1');
    expect(WordStatus.values.byName(target[9]).isRed, isTrue);
    expect(target[13].split(' ').first, isNot('t'), reason: 'heard d');
    final strict = out.words['strict']!.skip(1).map((l) => l.split(','));
    expect(strict.every((r) => r[9] != 'good'), isTrue);
    final clips = out.clips['default']!;
    expect(clips, hasLength(3));
    final c = clips[1].split(',');
    expect(c[clipCsvHeader.indexOf('audio_ms')], '1000');
    expect(c[clipCsvHeader.indexOf('model_ms')], '10');

    out.writeTo(Directory('${tmp.path}/out'));
    expect(File('${tmp.path}/out/words_strict.csv').existsSync(), isTrue);
    expect(
      File('${tmp.path}/out/clips_default.csv').readAsLinesSync(),
      hasLength(3),
    );

    await expectLater(
      runEval(
        items: [EvalItem(item: 'x', wav: w.path, passage: 'nope')],
        passages: const {},
        source: (path) async => TimedPosteriors(posteriorsFor(['k'])),
      ),
      throwsArgumentError,
    );
  });

  test('wordRows marks dropped sounds', () {
    final p = passage('pa', [
      ('cat', ['k', 'æ', 't']),
    ]);
    final rows = wordRows(
      'c',
      const EvalItem(item: 'pa', wav: 'w', passage: 'pa'),
      p,
      const [
        WordResult(
          index: 0,
          text: 'cat',
          score: 40,
          status: WordStatus.fix,
          phonemes: [
            PhonemeResult(
              expected: 'k',
              score: 90,
              start: Duration.zero,
              end: Duration.zero,
            ),
            PhonemeResult(
              expected: 'æ',
              heard: 'ɛ',
              score: 20,
              start: Duration.zero,
              end: Duration.zero,
            ),
            PhonemeResult(
              expected: 't',
              heard: '',
              score: 0,
              start: Duration.zero,
              end: Duration.zero,
            ),
          ],
        ),
      ],
    );
    expect(rows.single[13], 'k ɛ $droppedMark');
    expect(rows.single[14], '90 20 0');
  });

  test('parseConfigs', () {
    final f = File('${tmp.path}/c.json')
      ..writeAsStringSync(jsonEncode({'goodThreshold': 70}));
    final c = parseConfigs('default, tuned=${f.path},');
    expect(c.keys, ['default', 'tuned']);
    expect(c['tuned']!.goodThreshold, 70);
    expect(c['default']!.goodThreshold, 80);
    expect(parseConfigs('').keys, ['default']);
  });

  test('hostOrtLibraryPath reads the package config', () {
    expect(
      hostOrtLibraryPath(packageConfig: '${tmp.path}/missing.json'),
      isNull,
    );
    final plugin = Directory('${tmp.path}/ort/linux')
      ..createSync(recursive: true);
    File('${plugin.path}/libonnxruntime.so.1.22.0').writeAsBytesSync([0]);
    final cfg = File('${tmp.path}/package_config.json')
      ..writeAsStringSync(
        jsonEncode({
          'packages': [
            {'name': 'other', 'rootUri': 'file:///x'},
            {'name': 'onnxruntime_v2', 'rootUri': 'ort'},
          ],
        }),
      );
    final found = hostOrtLibraryPath(packageConfig: cfg.path);
    if (Platform.isLinux) {
      expect(found, endsWith('libonnxruntime.so.1.22.0'));
      Directory('${tmp.path}/ort/linux').deleteSync(recursive: true);
      expect(hostOrtLibraryPath(packageConfig: cfg.path), isNull);
    } else {
      expect(found, isNull);
    }
  });
}
