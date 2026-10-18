import 'dart:math' as math;
import 'dart:typed_data';

import 'phoneme_mapper.dart';

/// Result of [alignCtc]: which extended-CTC state each frame is in.
///
/// States: even `2k` is the blank before unit `k` (`2U` is the final blank), odd
/// `2k + 1` is unit `k`.
class CtcAlignment {
  /// Creates an alignment (see [alignCtc]).
  CtcAlignment({
    required this.stateOfFrame,
    required this.skipped,
    required this.unitStart,
    required this.unitEnd,
    required this.logScore,
  });

  /// State index per frame.
  final Int32List stateOfFrame;

  /// Per aligned word: true when the best path skipped it (not said).
  final List<bool> skipped;

  /// First frame of each unit, or -1 for units of skipped words.
  final Int32List unitStart;

  /// One past the last frame of each unit, or -1 for units of skipped words.
  final Int32List unitEnd;

  /// Log score of the best path (skip penalties included).
  final double logScore;
}

/// CTC Viterbi forced alignment of [units] (grouped into words by
/// [wordUnitCounts], each >= 1) to [frames] of log-posteriors.
///
/// Blanks between units are optional; a blank is required between two units that
/// accept the same symbols (the CTC repeat rule). Any word may be skipped at a
/// log cost of [skipPenalty]: the path jumps from the blank before the word (or its
/// previous unit) to the blank after it. Returns null when no path fits (fewer
/// frames than units).
///
/// For speed, states scoring more than [beam] below the frame's best state are
/// pruned, and states beyond the furthest reachable one are not evaluated.
CtcAlignment? alignCtc({
  required List<Float32List> frames,
  required int blankIndex,
  required List<PhonemeUnit> units,
  required List<int> wordUnitCounts,
  required double skipPenalty,
  double beam = 100,
}) {
  final nFrames = frames.length;
  final nUnits = units.length;
  final nStates = 2 * nUnits + 1;
  if (nFrames == 0 || nUnits == 0) return null;

  // Distinct unit types, so each frame evaluates each accepted set once.
  final typeOf = Int32List(nUnits);
  final types = <PhonemeUnit>[];
  for (var u = 0; u < nUnits; u++) {
    var t = types.indexWhere(units[u].sameAs);
    if (t < 0) {
      t = types.length;
      types.add(units[u]);
    }
    typeOf[u] = t;
  }
  final repeatOfPrev = Uint8List(nUnits);
  for (var u = 1; u < nUnits; u++) {
    if (typeOf[u] == typeOf[u - 1]) repeatOfPrev[u] = 1;
  }

  // Skip transitions: blank state after word w <- blank state before word w.
  final skipFrom = Int32List(nStates)..fillRange(0, nStates, -1);
  final skipWord = Int32List(nStates)..fillRange(0, nStates, -1);
  // reachMax[s]: furthest state reachable in one frame from any state <= s.
  final reachMax = Int32List(nStates);
  for (var s = 0; s < nStates; s++) {
    reachMax[s] = math.min(nStates - 1, s + 2);
  }
  var first = 0;
  for (var w = 0; w < wordUnitCounts.length; w++) {
    final after = 2 * (first + wordUnitCounts[w]);
    skipFrom[after] = 2 * first;
    skipWord[after] = w;
    reachMax[2 * first] = math.max(reachMax[2 * first], after);
    if (first > 0) {
      reachMax[2 * first - 1] = math.max(reachMax[2 * first - 1], after);
    }
    first += wordUnitCounts[w];
  }
  for (var s = 1; s < nStates; s++) {
    reachMax[s] = math.max(reachMax[s], reachMax[s - 1]);
  }

  const negInf = double.negativeInfinity;
  var prev = Float64List(nStates)..fillRange(0, nStates, negInf);
  var cur = Float64List(nStates)..fillRange(0, nStates, negInf);
  prev[0] = 0; // virtual start before frame 0
  // Back-pointers are stored only for each frame's evaluated window.
  var back = Uint8List(math.max(1024, nFrames * 64));
  final rowStart = Int32List(
    nFrames,
  ); // index in back of the window's first cell
  final rowLo = Int32List(nFrames); // first state of the window
  final typeEm = Float64List(types.length);
  // Live windows: prev holds [lo, hi]; cur still holds [cLo, cHi] from two
  // frames ago. Everything outside a window is -inf.
  var lo = 0;
  var hi = 0;
  var cLo = 0;
  var cHi = -1;
  var lastWidth = 0;

  for (var t = 0; t < nFrames; t++) {
    final f = frames[t];
    for (var k = 0; k < types.length; k++) {
      final ids = types[k].ids;
      var m = f[ids[0]].toDouble();
      for (var i = 1; i < ids.length; i++) {
        if (f[ids[i]] > m) m = f[ids[i]].toDouble();
      }
      typeEm[k] = m;
    }
    final blankEm = f[blankIndex].toDouble();
    final newHi = reachMax[hi];
    final rowBase = t == 0 ? 0 : rowStart[t - 1] + lastWidth;
    final need = rowBase + newHi - lo + 1;
    if (need > back.length) {
      back = Uint8List(math.max(need, back.length * 2))
        ..setRange(0, rowBase, back);
    }
    rowStart[t] = rowBase;
    rowLo[t] = lo;
    lastWidth = newHi - lo + 1;
    final row = rowBase - lo;
    cur.fillRange(cLo, cHi + 1, negInf);
    var bestNow = negInf;
    for (var s = lo; s <= newHi; s++) {
      var best = prev[s];
      var code = 0;
      if (s >= 1 && prev[s - 1] > best) {
        best = prev[s - 1];
        code = 1;
      }
      double em;
      if (s.isOdd) {
        final u = s >> 1;
        em = typeEm[typeOf[u]];
        if (s >= 3 && repeatOfPrev[u] == 0 && prev[s - 2] > best) {
          best = prev[s - 2];
          code = 2;
        }
      } else {
        em = blankEm;
        final src = skipFrom[s];
        if (src >= 0) {
          final v = prev[src] - skipPenalty;
          if (v > best) {
            best = v;
            code = 3;
          }
          if (src >= 1) {
            final v2 = prev[src - 1] - skipPenalty;
            if (v2 > best) {
              best = v2;
              code = 4;
            }
          }
        }
      }
      final v = best + em;
      cur[s] = v;
      back[row + s] = code;
      if (v > bestNow) bestNow = v;
    }
    // Prune states at both ends that fell out of the beam.
    final floor = bestNow - beam;
    var newLo = lo;
    while (newLo < newHi && !(cur[newLo] >= floor)) {
      cur[newLo] = negInf;
      newLo++;
    }
    var top = newHi;
    while (top > newLo && !(cur[top] >= floor)) {
      cur[top] = negInf;
      top--;
    }
    final tmp = prev;
    prev = cur;
    cur = tmp;
    cLo = lo;
    cHi = newHi;
    lo = newLo;
    hi = top;
  }

  var s = prev[nStates - 1] >= prev[nStates - 2] ? nStates - 1 : nStates - 2;
  final logScore = prev[s];
  if (logScore == negInf) return null;

  final stateOfFrame = Int32List(nFrames);
  final skipped = List<bool>.filled(wordUnitCounts.length, false);
  for (var t = nFrames - 1; t >= 0; t--) {
    stateOfFrame[t] = s;
    switch (back[rowStart[t] + s - rowLo[t]]) {
      case 1:
        s -= 1;
      case 2:
        s -= 2;
      case 3:
        skipped[skipWord[s]] = true;
        s = skipFrom[s];
      case 4:
        skipped[skipWord[s]] = true;
        s = skipFrom[s] - 1;
    }
  }

  final unitStart = Int32List(nUnits)..fillRange(0, nUnits, -1);
  final unitEnd = Int32List(nUnits)..fillRange(0, nUnits, -1);
  for (var t = 0; t < nFrames; t++) {
    final st = stateOfFrame[t];
    if (st.isOdd) {
      final u = st >> 1;
      if (unitStart[u] < 0) unitStart[u] = t;
      unitEnd[u] = t + 1;
    }
  }
  return CtcAlignment(
    stateOfFrame: stateOfFrame,
    skipped: skipped,
    unitStart: unitStart,
    unitEnd: unitEnd,
    logScore: logScore,
  );
}
