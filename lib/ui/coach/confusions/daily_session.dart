import '../../../core/contracts/voice_service.dart';
import '../../../core/models/models.dart';
import 'confusion_logic.dart';

/// Pairs in a session: two for the default 5 minutes, three from 8 minutes.
int pairsForMinutes(int minutes) => minutes >= 8 ? 3 : 2;

/// How many of the weakest sounds seed the fallback session.
const int weakSoundCount = 3;

/// What one step of the session asks the user to do.
enum SessionStepKind {
  /// Hear both words of the pair at [VoiceService.slowRate].
  listenSlow,

  /// Hear both words of the pair at normal speed.
  listenNormal,

  /// Say one word and get a [PairVerdict] estimate.
  say,
}

/// One step of today's session. Listen steps speak [words] in order; say steps have a
/// single target word, [words] of length 1, chosen by [sayA].
class SessionStep {
  /// Creates a step.
  const SessionStep({
    required this.kind,
    required this.pair,
    required this.words,
    required this.instruction,
    this.sayA = true,
  });

  /// What the user does.
  final SessionStepKind kind;

  /// The minimal pair this step drills.
  final MinimalPair pair;

  /// Words the voice speaks (listen steps) or the word to say (say steps).
  final List<String> words;

  /// One short line telling the user what to do.
  final String instruction;

  /// For say steps: true when the target is `pair.wordA`, false for `pair.wordB`.
  final bool sayA;

  /// Whether this step only plays audio.
  bool get isListen => kind != SessionStepKind.say;

  /// Speaking rate for the voice on listen steps.
  double get rate => kind == SessionStepKind.listenSlow
      ? VoiceService.slowRate
      : VoiceService.normalRate;

  /// The word to say on a say step.
  String get target => sayA ? pair.wordA : pair.wordB;

  /// The other word of the pair (the one a listener may hear instead).
  String get other => sayA ? pair.wordB : pair.wordA;
}

/// Builds today's session: four steps per pair (listen slowly, listen at normal speed,
/// say A, say B), for two or three pairs, so 8 to 12 steps. A single pair is repeated
/// once more so the session still reaches 8 steps. Empty when there are no pairs.
///
/// Pairs are chosen in this order, skipping duplicates:
/// 1. the first pair matching each confusion's contrast, in confusion order;
/// 2. the other pairs matching those contrasts;
/// 3. when there are fewer than needed, pairs for the [weakSoundCount] weakest sounds
///    in [soundStats] (only sounds with at least one attempt);
/// 4. when there are no confusions at all, every pair in the given order.
///
/// A contrast matches in either order, so `ʌ-æ` and `æ-ʌ` both match `ʌ` heard as `æ`.
/// Pure: no I/O.
List<SessionStep> buildDailySession(
  List<Confusion> confusions,
  List<MinimalPair> pairs, {
  int minutes = 5,
  List<SoundStat> soundStats = const <SoundStat>[],
}) {
  final max = pairsForMinutes(minutes);
  final ordered = <MinimalPair>[];
  for (final confusion in confusions) {
    final matches = pairs.where((p) => _matches(p, confusion)).toList();
    if (matches.isNotEmpty) ordered.add(matches.first);
  }
  for (final confusion in confusions) {
    ordered.addAll(pairs.where((p) => _matches(p, confusion)));
  }
  ordered.addAll(_pairsForWeakSounds(soundStats, pairs));
  if (confusions.isEmpty) ordered.addAll(pairs);

  final chosen = <MinimalPair>[];
  for (final pair in ordered) {
    if (chosen.length == max) break;
    if (!chosen.any((c) => _sameWords(c, pair))) chosen.add(pair);
  }
  if (chosen.isEmpty) return const <SessionStep>[];

  final rounds = chosen.length == 1 ? 2 : 1;
  return [
    for (var round = 0; round < rounds; round++)
      for (final pair in chosen) ..._stepsFor(pair),
  ];
}

/// Pairs whose contrast contains one of the [count] weakest sounds (accuracy ascending,
/// ties by ipa), in that sound order.
List<MinimalPair> _pairsForWeakSounds(
  List<SoundStat> stats,
  List<MinimalPair> pairs,
) {
  final weakest = stats.where((s) => s.attempts > 0).toList()
    ..sort((a, b) {
      final byAccuracy = a.accuracy.compareTo(b.accuracy);
      return byAccuracy != 0 ? byAccuracy : a.ipa.compareTo(b.ipa);
    });
  final result = <MinimalPair>[];
  for (final stat in weakest.take(weakSoundCount)) {
    for (final pair in pairs) {
      if (pair.contrast.split('-').contains(stat.ipa)) result.add(pair);
    }
  }
  return result;
}

bool _matches(MinimalPair pair, Confusion confusion) {
  final sides = pair.contrast.split('-');
  if (sides.length != 2) return false;
  return (sides[0] == confusion.expected && sides[1] == confusion.heard) ||
      (sides[0] == confusion.heard && sides[1] == confusion.expected);
}

bool _sameWords(MinimalPair a, MinimalPair b) =>
    a.wordA == b.wordA && a.wordB == b.wordB;

List<SessionStep> _stepsFor(MinimalPair pair) => [
  SessionStep(
    kind: SessionStepKind.listenSlow,
    pair: pair,
    words: [pair.wordA, pair.wordB],
    instruction: 'Listen slowly. Hear the vowel change.',
  ),
  SessionStep(
    kind: SessionStepKind.listenNormal,
    pair: pair,
    words: [pair.wordA, pair.wordB],
    instruction: 'Now listen at normal speed.',
  ),
  SessionStep(
    kind: SessionStepKind.say,
    pair: pair,
    words: [pair.wordA],
    sayA: true,
    instruction: 'Say "${pair.wordA}" clearly.',
  ),
  SessionStep(
    kind: SessionStepKind.say,
    pair: pair,
    words: [pair.wordB],
    sayA: false,
    instruction: 'Now say "${pair.wordB}".',
  ),
];

/// Day-level streak: one finished session per day keeps it going.
class SessionStreak {
  /// Creates a streak state. [lastSessionDate] is `yyyy-MM-dd` or null.
  const SessionStreak({this.lastSessionDate, this.streak = 0});

  /// Reads the stored object; a missing or malformed value counts as no streak.
  factory SessionStreak.fromJson(Map<String, Object?>? json) {
    if (json == null) return const SessionStreak();
    final last = json['lastSessionDate'];
    final streak = json['streak'];
    return SessionStreak(
      lastSessionDate: last is String ? last : null,
      streak: streak is int && streak >= 0 ? streak : 0,
    );
  }

  /// Day of the last finished session as `yyyy-MM-dd`, or null.
  final String? lastSessionDate;

  /// Consecutive days up to [lastSessionDate].
  final int streak;

  /// The stored form.
  Map<String, Object?> toJson() => <String, Object?>{
    'lastSessionDate': lastSessionDate,
    'streak': streak,
  };

  /// `yyyy-MM-dd` for [day] in local time.
  static String dayKey(DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// The state after a session finished on [today]. A second session on the same day
  /// changes nothing; the day after the last one extends the streak; any other gap
  /// starts again at 1.
  SessionStreak recordedOn(DateTime today) {
    final key = dayKey(today);
    if (lastSessionDate == key) return this;
    final yesterday = dayKey(DateTime(today.year, today.month, today.day - 1));
    return SessionStreak(
      lastSessionDate: key,
      streak: lastSessionDate == yesterday ? streak + 1 : 1,
    );
  }

  /// The streak to show on [today]: the stored count while the last session was today
  /// or yesterday, else 0.
  int currentAt(DateTime today) {
    final last = lastSessionDate;
    if (last == null) return 0;
    final yesterday = dayKey(DateTime(today.year, today.month, today.day - 1));
    return last == dayKey(today) || last == yesterday ? streak : 0;
  }
}
