import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/contracts/pronunciation_scorer.dart';
import '../../core/models/models.dart';
import 'config/scoring_config.dart';
import 'ctc_aligner.dart';
import 'data/phoneme_map.dart';
import 'fluency.dart';
import 'phoneme_mapper.dart';

/// Speech heard between expected words that matches none of them.
class ExtraSpeech {
  /// Creates a record of inserted speech.
  const ExtraSpeech({
    required this.startFrame,
    required this.endFrame,
    required this.phones,
    required this.words,
    this.repeatOf,
  });

  /// First frame of the region.
  final int startFrame;

  /// One past the last frame of the region.
  final int endFrame;

  /// Phones the model heard there (model symbols, in order).
  final List<String> phones;

  /// Estimated number of inserted words (0 when it is a repeat).
  final int words;

  /// Index of the neighbouring word it repeats, if any.
  final int? repeatOf;
}

/// Everything [GopPronunciationScorer.analyse] works out, for tests and the eval
/// harness. [words] and the scores are what `score` returns.
class ScoringAnalysis {
  /// Creates an analysis.
  const ScoringAnalysis({
    required this.words,
    required this.accuracy,
    required this.fluency,
    required this.extras,
    required this.alignment,
  });

  /// One result per passage word, in order.
  final List<WordResult> words;

  /// 0-100.
  final int accuracy;

  /// Fluency score and its parts.
  final FluencyBreakdown fluency;

  /// Inserted and repeated speech between words.
  final List<ExtraSpeech> extras;

  /// The forced alignment, or null when nothing could be aligned.
  final CtcAlignment? alignment;

  /// `round(0.7 * accuracy + 0.3 * fluency)`.
  int get overall => (0.7 * accuracy + 0.3 * fluency.score).round();
}

/// [PronunciationScorer] using CTC Viterbi forced alignment and goodness of
/// pronunciation (GOP). Pure Dart and synchronous.
///
/// 1. Each expected British phoneme is mapped to model symbols ([PhonemeMapper]).
/// 2. The expected phonemes are force-aligned to the posteriors ([alignCtc]);
///    words may be skipped at a cost, which marks them missed.
/// 3. Per phoneme, GOP = mean log-posterior of the expected symbols over its frames
///    minus that of the best competing symbol; the calibration curve in
///    [ScoringConfig] maps it to 0-100 and a winning competitor is reported as heard.
/// 4. Word score = weighted mean of phoneme scores (stressed vowels weigh 1.5);
///    accuracy = mean word score; fluency from rate, pauses and missed / extra /
///    repeated words ([computeFluency]); overall = 0.7 accuracy + 0.3 fluency.
class GopPronunciationScorer implements PronunciationScorer {
  /// Creates a scorer with [config] (defaults: A3's initial calibration).
  const GopPronunciationScorer({this.config = const ScoringConfig()});

  /// Calibration and thresholds.
  final ScoringConfig config;

  static final RegExp _punctuation = RegExp(r'[.,;:!?]');

  @override
  AttemptResult score(
    Passage passage,
    PhonemePosteriors posteriors,
    List<Segment> speech, {
    String? attemptId,
    DateTime? at,
    String? audioPath,
  }) {
    final when = at ?? DateTime.now();
    final a = analyse(passage, posteriors, speech);
    return AttemptResult(
      id: attemptId ?? 'attempt-${when.microsecondsSinceEpoch}',
      passageId: passage.id,
      at: when,
      overall: a.overall,
      accuracy: a.accuracy,
      fluency: a.fluency.score,
      words: a.words,
      audioPath: audioPath,
      tier: posteriors.tier,
    );
  }

  @override
  WordResult scoreWord(WordSpec word, PhonemePosteriors posteriors) {
    final single = Passage(
      id: 'word',
      level: 1,
      title: word.text,
      text: word.text,
      words: [word.copyWith(index: 0, offset: null)],
    );
    final r = analyse(single, posteriors, const []).words.single;
    return r.copyWith(index: word.index, text: word.text);
  }

  /// Scores [passage] and returns the details behind the result.
  ScoringAnalysis analyse(
    Passage passage,
    PhonemePosteriors posteriors,
    List<Segment> speech,
  ) => _Analysis(this, passage, posteriors, speech).run();
}

class _WordPlan {
  _WordPlan(
    this.index,
    this.word,
    this.firstUnit,
    this.phonemeFirstUnit,
    this.unitCount,
  );

  /// Position among aligned words (index into `CtcAlignment.skipped`).
  final int index;
  final WordSpec word;
  final int firstUnit;
  final List<int> phonemeFirstUnit;
  final int unitCount;

  int unitsOf(int p) =>
      (p + 1 < phonemeFirstUnit.length
          ? phonemeFirstUnit[p + 1]
          : firstUnit + unitCount) -
      phonemeFirstUnit[p];
}

class _PhonemeStats {
  _PhonemeStats(this.score, this.heard, this.start, this.end);
  int score;
  String? heard;
  final int start;
  final int end;
}

class _Analysis {
  _Analysis(this.scorer, this.passage, this.post, this.speech)
    : config = scorer.config,
      vocab = ModelVocab(
        List<String>.of(post.vocab, growable: false),
        post.blankIndex,
      ),
      // Plain list copy: freezed wraps model lists in unmodifiable views, which
      // are slow in the hot loops.
      frames = List<Float32List>.of(post.frames, growable: false) {
    mapper = PhonemeMapper(vocab, extraAccepted: config.extraAccepted);
    speechProb = Float64List(frames.length);
    for (var t = 0; t < frames.length; t++) {
      speechProb[t] = 1 - math.exp(frames[t][vocab.blankIndex]);
    }
    top = Int32List(frames.length * _topK);
    topDone = Uint8List(frames.length);
  }

  final GopPronunciationScorer scorer;
  final ScoringConfig config;
  final Passage passage;
  final PhonemePosteriors post;
  final List<Segment> speech;
  final ModelVocab vocab;
  final List<Float32List> frames;
  late final PhonemeMapper mapper;
  late final Float64List speechProb;

  /// Best [_topK] phone ids per frame (best first, -1 padded), filled lazily.
  late final Int32List top;
  late final Uint8List topDone;
  static const int _topK = 4;

  final List<_WordPlan> plans = [];
  final List<PhonemeUnit> units = [];
  CtcAlignment? align;

  int ms(int frame) => frame * post.frameMs;

  /// Offset of frame [t]'s best phone ids in [top].
  int topOf(int t) {
    final base = t * _topK;
    if (topDone[t] == 0) {
      topDone[t] = 1;
      final f = frames[t];
      final ids = vocab.phoneIds;
      final best = Float64List(_topK)
        ..fillRange(0, _topK, double.negativeInfinity);
      top.fillRange(base, base + _topK, -1);
      for (var i = 0; i < ids.length; i++) {
        final v = f[ids[i]];
        if (v <= best[_topK - 1]) continue;
        var k = _topK - 1;
        while (k > 0 && v > best[k - 1]) {
          best[k] = best[k - 1];
          top[base + k] = top[base + k - 1];
          k--;
        }
        best[k] = v;
        top[base + k] = ids[i];
      }
    }
    return base;
  }

  /// Best phone id of frame [t] when the frame is speech, else -1.
  int speechPhone(int t) {
    if (speechProb[t] < config.speechFrameMinProb) return -1;
    return top[topOf(t)];
  }

  ScoringAnalysis run() {
    final planOf = <int, _WordPlan>{};
    for (final w in passage.words) {
      if (!w.scorable) continue;
      final firsts = <int>[];
      final start = units.length;
      for (final p in w.phonemes) {
        firsts.add(units.length);
        units.addAll(mapper.unitsFor(p.ipa));
      }
      if (units.length == start) continue; // nothing mappable: reported missed
      final plan = _WordPlan(
        plans.length,
        w,
        start,
        firsts,
        units.length - start,
      );
      plans.add(plan);
      planOf[w.index] = plan;
    }
    align = alignCtc(
      frames: frames,
      blankIndex: vocab.blankIndex,
      units: units,
      wordUnitCounts: [for (final p in plans) p.unitCount],
      skipPenalty: config.skipWordPenalty,
    );
    final results = <WordResult>[];
    final spans = <WordSpan>[];
    var notScored = 0;
    for (final w in passage.words) {
      if (!w.scorable) {
        notScored++;
        results.add(
          WordResult(
            index: w.index,
            text: w.text,
            score: 0,
            status: WordStatus.notScored,
          ),
        );
        continue;
      }
      final plan = planOf[w.index];
      final a = align;
      if (plan == null || a == null || a.skipped[plan.index]) {
        results.add(_missed(w));
        continue;
      }
      final r = _scoreWord(plan);
      results.add(r ?? _missed(w));
      if (r != null) {
        spans.add((
          word: w.index,
          startMs: ms(a.unitStart[plan.firstUnit]),
          endMs: ms(a.unitEnd[plan.firstUnit + plan.unitCount - 1]),
        ));
      }
    }
    final extras = _extraSpeech();
    final scored = results.where((r) => r.status != WordStatus.notScored);
    final accuracy = scored.isEmpty
        ? 0
        : (scored.fold<int>(0, (s, r) => s + r.score) / scored.length).round();
    final sorted = [...speech]..sort((a, b) => a.start.compareTo(b.start));
    final fluency = computeFluency(
      config: config,
      spoken: spans,
      spokenWordCount: spans.length + notScored,
      totalWords: passage.words.length,
      missedWords: results.where((r) => r.status == WordStatus.missed).length,
      extraWords: extras.fold(0, (s, e) => s + e.words),
      repeatedWords: extras.where((e) => e.repeatOf != null).length,
      silencesMs: [
        for (var i = 1; i < sorted.length; i++)
          (sorted[i - 1].end.inMilliseconds, sorted[i].start.inMilliseconds),
      ],
      punctuationAfter: _punctuationAfter,
    );
    return ScoringAnalysis(
      words: results,
      accuracy: accuracy,
      fluency: fluency,
      extras: extras,
      alignment: align,
    );
  }

  WordResult _missed(WordSpec w) => WordResult(
    index: w.index,
    text: w.text,
    score: 0,
    status: WordStatus.missed,
  );

  bool _punctuationAfter(int i) {
    final words = passage.words;
    if (i + 1 >= words.length) return false;
    final a = words[i];
    final b = words[i + 1];
    if (a.offset == null || b.offset == null) return false;
    final from = a.offset! + a.text.length;
    if (from > b.offset! || b.offset! > passage.text.length) return false;
    return passage.text
        .substring(from, b.offset!)
        .contains(GopPronunciationScorer._punctuation);
  }

  /// Scores an aligned word; null when it was not really said.
  WordResult? _scoreWord(_WordPlan plan) {
    final a = align!;
    final w = plan.word;
    var speechSum = 0.0;
    var speechFrames = 0;
    for (var u = plan.firstUnit; u < plan.firstUnit + plan.unitCount; u++) {
      for (var t = a.unitStart[u]; t < a.unitEnd[u]; t++) {
        speechSum += speechProb[t];
        speechFrames++;
      }
    }
    if (speechSum / speechFrames < config.missedSpeechThreshold) return null;

    final stats = <_PhonemeStats?>[];
    for (var p = 0; p < w.phonemes.length; p++) {
      stats.add(plan.unitsOf(p) == 0 ? null : _scorePhoneme(plan, p));
    }
    if (stats.every((x) => x == null || x.heard == '')) return null;
    _checkIntrusiveR(plan, stats);

    // Unmappable phonemes take the word's mean score and a zero-length span.
    final known = stats.whereType<_PhonemeStats>().toList();
    final meanScore = known.isEmpty
        ? 0
        : (known.fold<int>(0, (s, x) => s + x.score) / known.length).round();
    final phonemes = <PhonemeResult>[];
    var cursor = known.first.start;
    var sum = 0.0;
    var weight = 0.0;
    for (var p = 0; p < w.phonemes.length; p++) {
      final spec = w.phonemes[p];
      final s = stats[p];
      int end;
      if (s == null) {
        end = cursor;
      } else {
        end = s.end;
        for (var q = p + 1; q < stats.length; q++) {
          if (stats[q] != null) {
            end = stats[q]!.start;
            break;
          }
        }
      }
      final start = s?.start ?? cursor;
      final score = s?.score ?? meanScore;
      phonemes.add(
        PhonemeResult(
          expected: spec.ipa,
          heard: s?.heard,
          score: score,
          start: Duration(milliseconds: ms(start)),
          end: Duration(milliseconds: ms(end)),
        ),
      );
      cursor = end;
      final wt = spec.stress == 1 ? config.stressedVowelWeight : 1.0;
      sum += score * wt;
      weight += wt;
    }
    final worst = phonemes.fold(100, (m, ph) => math.min(m, ph.score));
    final score = math
        .min(sum / weight, worst + config.wordMaxAboveWorst)
        .round()
        .clamp(0, 100)
        .toInt();
    return WordResult(
      index: w.index,
      text: w.text,
      score: score,
      phonemes: phonemes,
      status: WordStatus.fromScore(
        score,
        good: config.goodThreshold,
        close: config.closeThreshold,
      ),
    );
  }

  _PhonemeStats _scorePhoneme(_WordPlan plan, int p) {
    final a = align!;
    final first = plan.phonemeFirstUnit[p];
    final n = plan.unitsOf(p);
    var gopSum = 0.0;
    final heardParts = <String>[];
    var anyHeard = false;
    final candidates = <int>[];
    for (var u = first; u < first + n; u++) {
      final ids = units[u].ids;
      var expSum = 0.0;
      final s = a.unitStart[u];
      final e = a.unitEnd[u];
      // Competitors: phones in the top few of any frame (the best competitor by
      // mean log-posterior is, in practice, always among them).
      candidates.clear();
      for (var t = s; t < e; t++) {
        final f = frames[t];
        var m = f[ids[0]].toDouble();
        for (var i = 1; i < ids.length; i++) {
          if (f[ids[i]] > m) m = f[ids[i]].toDouble();
        }
        expSum += m;
        final base = topOf(t);
        for (var k = base; k < base + _topK; k++) {
          final q = top[k];
          if (q >= 0 && !ids.contains(q) && !candidates.contains(q)) {
            candidates.add(q);
          }
        }
      }
      var best = -1;
      var bestSum = double.negativeInfinity;
      for (final q in candidates) {
        var sum = 0.0;
        for (var t = s; t < e; t++) {
          sum += frames[t][q];
        }
        if (sum > bestSum) {
          bestSum = sum;
          best = q;
        }
      }
      final frameCount = e - s;
      final expMean = expSum / frameCount;
      final compMean = bestSum / frameCount;
      gopSum += expMean - compMean;
      if (compMean - expMean > config.heardMargin) {
        anyHeard = true;
        heardParts.add(vocab.symbols[best]);
      } else {
        heardParts.add(vocab.symbols[ids.first]);
      }
    }
    final start = a.unitStart[first];
    final end = a.unitEnd[first + n - 1];
    if (!_hasOwnSpeech(first, n, start, end)) {
      return _PhonemeStats(config.droppedScore, '', start, end);
    }
    return _PhonemeStats(
      config.phonemeScore(gopSum / n),
      anyHeard ? heardParts.join() : null,
      start,
      end,
    );
  }

  /// True when some frame of the phoneme (units `[first, first + n)`) is speech
  /// that is not just the neighbouring phonemes' sound squeezed in by the forced
  /// alignment; otherwise the sound was dropped.
  bool _hasOwnSpeech(int first, int n, int start, int end) {
    final own = units[first];
    final neighbours = [
      if (first > 0 && !units[first - 1].sameAs(own)) units[first - 1],
      if (first + n < units.length &&
          !units[first + n].sameAs(units[first + n - 1]))
        units[first + n],
    ];
    for (var t = start; t < end; t++) {
      final id = speechPhone(t);
      if (id >= 0 && !neighbours.any((u) => u.ids.contains(id))) return true;
    }
    return false;
  }

  /// Flags vowels followed by a sounded r (British English is non-rhotic).
  void _checkIntrusiveR(_WordPlan plan, List<_PhonemeStats?> stats) {
    final a = align!;
    final phonemes = plan.word.phonemes;
    for (var p = 0; p < phonemes.length; p++) {
      final s = stats[p];
      final ipa = normalizeIpa(phonemes[p].ipa);
      if (s == null || s.heard != null || !ssbeVowels.contains(ipa)) continue;
      int limit;
      if (p + 1 < phonemes.length) {
        if (_isR(phonemes[p + 1].ipa) || stats[p + 1] == null) continue;
        limit = stats[p + 1]!.end;
      } else {
        final next = _nextSpokenPlan(plan.index);
        if (next != null) {
          final ph = next.word.phonemes.first.ipa;
          if (_isR(ph) || ssbeVowels.contains(normalizeIpa(ph))) continue;
          limit = a.unitEnd[next.firstUnit];
        } else {
          limit = frames.length;
        }
      }
      limit = math.min(limit, s.end + config.intrusiveRWindowFrames);
      for (var t = s.start; t < limit; t++) {
        final id = speechPhone(t);
        if (id >= 0 && rhoticSymbols.contains(vocab.symbols[id])) {
          s.heard = '${phonemes[p].ipa}ɹ';
          s.score = math.min(s.score, config.intrusiveRScore);
          break;
        }
      }
    }
  }

  static bool _isR(String ipa) {
    final n = normalizeIpa(ipa);
    return n == 'ɹ' || n == 'r';
  }

  _WordPlan? _nextSpokenPlan(int planIndex) {
    for (var i = planIndex + 1; i < plans.length; i++) {
      if (!align!.skipped[i]) return plans[i];
    }
    return null;
  }

  List<ExtraSpeech> _extraSpeech() {
    final a = align;
    if (a == null) return const [];
    final interWord = List<bool>.filled(units.length + 1, false);
    interWord[units.length] = true;
    final endingAt = <int, _WordPlan>{};
    final startingAt = <int, _WordPlan>{};
    for (var i = 0; i < plans.length; i++) {
      final pl = plans[i];
      interWord[pl.firstUnit] = true;
      if (!a.skipped[i]) {
        endingAt[pl.firstUnit + pl.unitCount] = pl;
        startingAt[pl.firstUnit] = pl;
      }
    }
    bool between(int t) {
      final s = a.stateOfFrame[t];
      return s.isEven && interWord[s >> 1];
    }

    final extras = <ExtraSpeech>[];
    var t = 0;
    while (t < frames.length) {
      if (!between(t)) {
        t++;
        continue;
      }
      final start = t;
      final phoneIds = <int>[];
      var last = -1;
      while (t < frames.length && between(t)) {
        final id = speechPhone(t);
        if (id >= 0 && id != last) phoneIds.add(id);
        last = id;
        t++;
      }
      if (phoneIds.length < config.extraWordMinPhones) continue;
      final before = endingAt[a.stateOfFrame[start] >> 1];
      final after = startingAt[a.stateOfFrame[t - 1] >> 1];
      int? repeatOf;
      for (final pl in [before, after]) {
        if (pl != null &&
            _similarity(phoneIds, pl) >= config.repeatSimilarity) {
          repeatOf = pl.word.index;
          break;
        }
      }
      extras.add(
        ExtraSpeech(
          startFrame: start,
          endFrame: t,
          phones: [for (final id in phoneIds) vocab.symbols[id]],
          words: repeatOf != null
              ? 0
              : (phoneIds.length / config.phonesPerExtraWord).ceil(),
          repeatOf: repeatOf,
        ),
      );
    }
    return extras;
  }

  /// Longest common subsequence of [ids] and [plan]'s units over the longer length.
  double _similarity(List<int> ids, _WordPlan plan) {
    final us = units.sublist(plan.firstUnit, plan.firstUnit + plan.unitCount);
    final dp = List.generate(ids.length + 1, (_) => Int32List(us.length + 1));
    for (var i = 1; i <= ids.length; i++) {
      for (var j = 1; j <= us.length; j++) {
        dp[i][j] = us[j - 1].ids.contains(ids[i - 1])
            ? dp[i - 1][j - 1] + 1
            : math.max(dp[i - 1][j], dp[i][j - 1]);
      }
    }
    return dp[ids.length][us.length] / math.max(ids.length, us.length);
  }
}
