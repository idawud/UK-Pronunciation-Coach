import '../../../core/contracts/clock.dart';
import '../../../data/coach/coach_store.dart';
import 'leitner.dart' as leitner;
import 'lost_word.dart';

/// Store key for the lost-word bank in [CoachStore].
const String lostWordsKey = 'lostWords';

/// Schema version written under the bank's key.
const int lostWordsVersion = 1;

/// The lost-word bank over [CoachStore], using [Clock] for every time it stamps.
///
/// Words are identified by [LostWord.keyOf] (trimmed, case-insensitive). Every
/// operation runs one at a time, so a read-modify-write cannot lose another call's
/// change. Malformed entries in the store are skipped rather than failing the bank.
class LostWordRepository {
  /// Creates the repository over [_store], stamping times with [_clock].
  LostWordRepository({required this._store, required this._clock});

  final CoachStore _store;
  final Clock _clock;

  /// Tail of the operation queue; each call waits for the previous one.
  Future<void> _tail = Future<void>.value();

  /// Adds [word] with an optional [note]. The word is trimmed; an empty word, or one
  /// already in the bank (case-insensitive), is ignored.
  ///
  /// Returns true when the word was added. The new word is in box 1 and due now.
  Future<bool> add(String word, {String? note}) => _serial(() async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return false;
    final words = await _readAll();
    final key = LostWord.keyOf(trimmed);
    if (words.any((w) => w.key == key)) return false;
    final cleanNote = note?.trim();
    final now = _clock();
    words.add(
      LostWord(
        word: trimmed,
        note: cleanNote == null || cleanNote.isEmpty ? null : cleanNote,
        addedAt: now,
        due: now,
      ),
    );
    await _writeAll(words);
    return true;
  });

  /// Every saved word, newest first.
  Future<List<LostWord>> list() => _serial(() async {
    final words = await _readAll();
    words.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return words;
  });

  /// Words due at the current clock time, most overdue first.
  Future<List<LostWord>> dueNow() => _serial(() async {
    final now = _clock();
    final words = (await _readAll())
        .where((w) => leitner.isDue(w, now))
        .toList();
    words.sort((a, b) => a.due.compareTo(b.due));
    return words;
  });

  /// Applies a review answer to [word] and saves it. Returns the updated word, or
  /// null when [word] is not in the bank.
  Future<LostWord?> review(String word, {required bool recalled}) =>
      _serial(() async {
        final words = await _readAll();
        final index = words.indexWhere((w) => w.key == LostWord.keyOf(word));
        if (index < 0) return null;
        final updated = leitner.review(words[index], recalled, _clock());
        words[index] = updated;
        await _writeAll(words);
        return updated;
      });

  /// Removes [word] from the bank. Returns true when a word was removed.
  Future<bool> remove(String word) => _serial(() async {
    final words = await _readAll();
    final before = words.length;
    words.removeWhere((w) => w.key == LostWord.keyOf(word));
    if (words.length == before) return false;
    await _writeAll(words);
    return true;
  });

  Future<T> _serial<T>(Future<T> Function() action) {
    final run = _tail.then((_) => action());
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<List<LostWord>> _readAll() async {
    final raw = await _store.read(lostWordsKey);
    final entries = raw?['words'];
    if (entries is! List<Object?>) return <LostWord>[];
    final words = <LostWord>[];
    for (final entry in entries) {
      if (entry is! Map<String, Object?>) continue;
      try {
        words.add(LostWord.fromJson(entry));
      } on FormatException {
        continue;
      }
    }
    return words;
  }

  Future<void> _writeAll(List<LostWord> words) => _store.write(lostWordsKey, {
    'version': lostWordsVersion,
    'words': [for (final w in words) w.toJson()],
  });
}
