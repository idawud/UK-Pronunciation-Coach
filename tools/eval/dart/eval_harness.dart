/// I2-eval accuracy harness: runs the real engine (a [PhonemeRecognizer] for the
/// posteriors, [GopPronunciationScorer] for the scores) over a manifest of WAV clips
/// and passages and writes per-word and per-clip CSVs.
///
/// The model-free parts (manifest, posterior cache, scoring, CSV) live here so they
/// can be unit-tested with canned posteriors; `run_eval_test.dart` wires in the
/// ONNX recognizer on the desktop host.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/engine/scoring/scoring.dart';

/// One scored item: a clip plus the passage it is scored against.
class EvalItem {
  /// Creates an item.
  const EvalItem({
    required this.item,
    required this.wav,
    required this.passage,
    this.speaker = '',
    this.split = '',
    this.kind = 'native',
    this.target,
    this.probe = '',
  });

  /// Item id (unique per manifest row).
  final String item;

  /// WAV path (relative paths resolve against the manifest's data folder).
  final String wav;

  /// Passage id in the passages JSON.
  final String passage;

  /// Speaker id.
  final String speaker;

  /// `tune` / `heldout` / `learner`.
  final String split;

  /// `native`, `swap`, `sub` or `learner`.
  final String kind;

  /// Word index that a probe expects to be red.
  final int? target;

  /// Probe description.
  final String probe;
}

/// Parses a tab-separated manifest with a header row. Needs `item`, `wav` and
/// `passage` columns; `speaker`, `split`, `kind`, `target`, `probe` are optional.
List<EvalItem> parseManifest(String tsv, {String dataDir = ''}) {
  final lines = const LineSplitter()
      .convert(tsv)
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return const [];
  final header = lines.first.split('\t');
  int col(String name) => header.indexOf(name);
  for (final need in ['item', 'wav', 'passage']) {
    if (col(need) < 0) throw FormatException('manifest needs a "$need" column');
  }
  String get(List<String> row, String name) {
    final i = col(name);
    return i < 0 || i >= row.length ? '' : row[i];
  }

  return [
    for (final line in lines.skip(1))
      () {
        final row = line.split('\t');
        final wav = get(row, 'wav');
        final kind = get(row, 'kind');
        return EvalItem(
          item: get(row, 'item'),
          wav: wav.startsWith('/') || dataDir.isEmpty ? wav : '$dataDir/$wav',
          passage: get(row, 'passage'),
          speaker: get(row, 'speaker'),
          split: get(row, 'split'),
          kind: kind.isEmpty ? 'native' : kind,
          target: int.tryParse(get(row, 'target')),
          probe: get(row, 'probe'),
        );
      }(),
  ];
}

/// Parses a JSON list of `Passage` objects into a map by id.
Map<String, Passage> parsePassages(String json) => {
  for (final p in jsonDecode(json) as List<dynamic>)
    (p as Map<String, dynamic>)['id'] as String: Passage.fromJson(p),
};

/// Duration of a 16-bit PCM WAV from its header (data bytes / byte rate).
Duration wavDuration(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var byteRate = 32000;
  var pos = 12;
  while (pos + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(pos, pos + 4));
    final size = data.getUint32(pos + 4, Endian.little);
    if (id == 'fmt ') byteRate = data.getUint32(pos + 12, Endian.little);
    if (id == 'data') {
      final n = size.clamp(0, bytes.length - pos - 8);
      return Duration(microseconds: n * 1000000 ~/ byteRate);
    }
    pos += 8 + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('WAV has no data chunk');
}

/// Posteriors plus how they were obtained.
class TimedPosteriors {
  /// Creates a record.
  const TimedPosteriors(this.posteriors, {this.modelMs, this.totalMs});

  /// The model output.
  final PhonemePosteriors posteriors;

  /// Model time alone (null when read from the cache).
  final int? modelMs;

  /// End-to-end recognise time (null when read from the cache).
  final int? totalMs;
}

/// Produces posteriors for a WAV (the recognizer, a cache, or canned data in tests).
typedef PosteriorSource = Future<TimedPosteriors> Function(String wavPath);

/// Disk cache for posteriors, keyed by the WAV's content and a model id, so
/// calibration runs re-score without re-running the model.
class PosteriorCache {
  /// Uses [dir]; [modelId] separates different models' outputs.
  PosteriorCache(this.dir, this.modelId);

  /// Cache folder.
  final Directory dir;

  /// Model identifier (e.g. the model file's size and name).
  final String modelId;

  String _key(String wavPath) {
    final h = sha1.convert([
      ...File(wavPath).readAsBytesSync(),
      ...utf8.encode(modelId),
    ]);
    return '${dir.path}/$h';
  }

  /// Cached posteriors, or null.
  PhonemePosteriors? read(String wavPath) {
    final k = _key(wavPath);
    final meta = File('$k.json');
    final data = File('$k.f32');
    if (!meta.existsSync() || !data.existsSync()) return null;
    final m = jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>;
    final vocab = [for (final s in m['vocab'] as List<dynamic>) s as String];
    final all = data.readAsBytesSync().buffer.asFloat32List();
    final n = vocab.length;
    return PhonemePosteriors(
      vocab: vocab,
      frames: [
        for (var t = 0; t < all.length ~/ n; t++)
          Float32List.sublistView(all, t * n, (t + 1) * n),
      ],
      blankIndex: m['blankIndex'] as int,
      frameMs: m['frameMs'] as int,
      tier: ModelTier.values.byName(m['tier'] as String),
    );
  }

  /// Stores [p] for [wavPath].
  void write(String wavPath, PhonemePosteriors p) {
    dir.createSync(recursive: true);
    final k = _key(wavPath);
    final n = p.vocab.length;
    final all = Float32List(p.frames.length * n);
    for (var t = 0; t < p.frames.length; t++) {
      all.setRange(t * n, (t + 1) * n, p.frames[t]);
    }
    File('$k.f32').writeAsBytesSync(all.buffer.asUint8List());
    File('$k.json').writeAsStringSync(
      jsonEncode({
        'vocab': p.vocab,
        'blankIndex': p.blankIndex,
        'frameMs': p.frameMs,
        'tier': p.tier.name,
      }),
    );
  }

  /// Wraps [source] with this cache.
  PosteriorSource wrap(PosteriorSource source) => (wav) async {
    final hit = read(wav);
    if (hit != null) return TimedPosteriors(hit);
    final fresh = await source(wav);
    write(wav, fresh.posteriors);
    return fresh;
  };
}

/// Header of the per-word CSV.
const wordCsvHeader = [
  'config',
  'item',
  'speaker',
  'split',
  'kind',
  'passage',
  'word_index',
  'word',
  'is_target',
  'status',
  'score',
  'expected',
  'stress',
  'heard',
  'phoneme_scores',
];

/// Header of the per-clip CSV.
const clipCsvHeader = [
  'config',
  'item',
  'speaker',
  'split',
  'kind',
  'probe',
  'accuracy',
  'fluency',
  'overall',
  'frames',
  'audio_ms',
  'model_ms',
  'recognise_ms',
  'score_ms',
];

/// Symbol written in the `heard` column for a dropped sound.
const droppedMark = '∅';

/// Quotes a CSV field when needed.
String csvField(Object? v) {
  final s = v?.toString() ?? '';
  return s.contains(RegExp('[,"\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
}

/// One CSV line.
String csvLine(List<Object?> fields) => fields.map(csvField).join(',');

/// Per-word rows for one scored item.
List<List<Object?>> wordRows(
  String config,
  EvalItem item,
  Passage passage,
  List<WordResult> words,
) => [
  for (final w in words)
    () {
      final spec = passage.words[w.index];
      final ph = w.phonemes;
      return <Object?>[
        config,
        item.item,
        item.speaker,
        item.split,
        item.kind,
        item.passage,
        w.index,
        w.text,
        item.target == w.index ? 1 : 0,
        w.status.name,
        w.score,
        spec.phonemes.map((p) => p.ipa).join(' '),
        spec.phonemes.map((p) => p.stress).join(' '),
        ph.isEmpty
            ? ''
            : ph
                  .map(
                    (p) => p.heard == null
                        ? p.expected
                        : p.heard!.isEmpty
                        ? droppedMark
                        : p.heard!,
                  )
                  .join(' '),
        ph.map((p) => p.score).join(' '),
      ];
    }(),
];

/// Results of a harness run, as CSV lines per config.
class EvalOutput {
  /// Word CSV lines (with header) per config name.
  final Map<String, List<String>> words = {};

  /// Clip CSV lines (with header) per config name.
  final Map<String, List<String>> clips = {};

  /// Writes `words_<config>.csv` and `clips_<config>.csv` into [dir].
  void writeTo(Directory dir) {
    dir.createSync(recursive: true);
    for (final e in words.entries) {
      File('${dir.path}/words_${e.key}.csv')
          .writeAsStringSync('${e.value.join('\n')}\n');
    }
    for (final e in clips.entries) {
      File('${dir.path}/clips_${e.key}.csv')
          .writeAsStringSync('${e.value.join('\n')}\n');
    }
  }
}

/// Scores every item with every config. Posteriors are fetched once per WAV.
Future<EvalOutput> runEval({
  required List<EvalItem> items,
  required Map<String, Passage> passages,
  required PosteriorSource source,
  Map<String, ScoringConfig> configs = const {'default': ScoringConfig()},
  void Function(String message)? log,
}) async {
  final out = EvalOutput();
  final scorers = {
    for (final e in configs.entries)
      e.key: GopPronunciationScorer(config: e.value),
  };
  for (final name in configs.keys) {
    out.words[name] = [csvLine(wordCsvHeader)];
    out.clips[name] = [csvLine(clipCsvHeader)];
  }
  final byWav = <String, List<EvalItem>>{};
  for (final it in items) {
    (byWav[it.wav] ??= []).add(it);
  }
  var done = 0;
  for (final MapEntry(key: wav, value: group) in byWav.entries) {
    final audioMs = wavDuration(File(wav).readAsBytesSync()).inMilliseconds;
    final tp = await source(wav);
    final post = tp.posteriors;
    for (final it in group) {
      final passage = passages[it.passage];
      if (passage == null) {
        throw ArgumentError('item ${it.item}: unknown passage ${it.passage}');
      }
      for (final MapEntry(key: name, value: scorer) in scorers.entries) {
        final sw = Stopwatch()..start();
        final a = scorer.analyse(passage, post, const []);
        sw.stop();
        out.words[name]!.addAll(
          wordRows(name, it, passage, a.words).map(csvLine),
        );
        out.clips[name]!.add(
          csvLine([
            name,
            it.item,
            it.speaker,
            it.split,
            it.kind,
            it.probe,
            a.accuracy,
            a.fluency.score,
            a.overall,
            post.frames.length,
            audioMs,
            tp.modelMs,
            tp.totalMs,
            (sw.elapsedMicroseconds / 1000).toStringAsFixed(2),
          ]),
        );
      }
    }
    done++;
    log?.call('[$done/${byWav.length}] $wav');
  }
  return out;
}

/// Reads configs from `name=path.json,name2=path2.json` (`default` = built-in).
Map<String, ScoringConfig> parseConfigs(String spec) {
  final out = <String, ScoringConfig>{};
  for (final part in spec.split(',')) {
    if (part.trim().isEmpty) continue;
    final i = part.indexOf('=');
    final name = i < 0 ? part.trim() : part.substring(0, i).trim();
    final path = i < 0 ? '' : part.substring(i + 1).trim();
    out[name] = path.isEmpty
        ? const ScoringConfig()
        : ScoringConfig.fromJson(
            jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
          );
  }
  return out.isEmpty ? {'default': const ScoringConfig()} : out;
}
