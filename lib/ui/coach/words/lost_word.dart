/// A word the user lost mid-sentence, kept in the Coach lost-word bank.
///
/// Immutable and hand-serialised (no codegen). Dates are stored as UTC ISO-8601
/// strings and read back as local time, so a bank moved between time zones keeps
/// the same instants.
class LostWord {
  /// Creates a lost word. [box] is the Leitner box (1 to 5) and [lapses] counts
  /// misses; a new word starts in box 1, due at once, with no lapses.
  const LostWord({
    required this.word,
    this.note,
    required this.addedAt,
    required this.due,
    this.box = 1,
    this.lapses = 0,
  });

  /// Parses a word from [json], as written by [toJson].
  ///
  /// Throws [FormatException] when a required field is missing or has the wrong type.
  /// [box] is clamped to 1-5 and [lapses] to zero or more.
  factory LostWord.fromJson(Map<String, Object?> json) {
    final word = json['word'];
    final note = json['note'];
    final addedAt = json['addedAt'];
    final due = json['due'];
    final box = json['box'];
    final lapses = json['lapses'];
    if (word is! String || word.trim().isEmpty) {
      throw const FormatException('LostWord.word must be a non-empty string');
    }
    if (note != null && note is! String) {
      throw const FormatException('LostWord.note must be a string or null');
    }
    if (addedAt is! String || due is! String) {
      throw const FormatException('LostWord dates must be ISO-8601 strings');
    }
    if (box is! int || lapses is! int) {
      throw const FormatException('LostWord.box and lapses must be integers');
    }
    return LostWord(
      word: word,
      note: note is String ? note : null,
      addedAt: _parseDate(addedAt, 'addedAt'),
      due: _parseDate(due, 'due'),
      box: box.clamp(1, 5),
      lapses: lapses < 0 ? 0 : lapses,
    );
  }

  /// The word as the user typed it (trimmed).
  final String word;

  /// What the user was trying to say, or null when none was given.
  final String? note;

  /// When the word was added.
  final DateTime addedAt;

  /// Leitner box, 1 (learning) to 5 (well known).
  final int box;

  /// When the word is next due. Due when this is not after the current time.
  final DateTime due;

  /// How many times the user missed the word in review.
  final int lapses;

  /// Identity used for de-duplication: trimmed and lower-cased.
  String get key => keyOf(word);

  /// The identity key for [word], so "Scaffold " and "scaffold" match.
  static String keyOf(String word) => word.trim().toLowerCase();

  /// Returns a copy with the given fields replaced.
  LostWord copyWith({
    String? word,
    String? note,
    DateTime? addedAt,
    int? box,
    DateTime? due,
    int? lapses,
  }) => LostWord(
    word: word ?? this.word,
    note: note ?? this.note,
    addedAt: addedAt ?? this.addedAt,
    box: box ?? this.box,
    due: due ?? this.due,
    lapses: lapses ?? this.lapses,
  );

  /// JSON map for the Coach store. `note` is omitted when null.
  Map<String, Object?> toJson() {
    final note = this.note;
    return {
      'word': word,
      'note': ?note,
      'addedAt': addedAt.toUtc().toIso8601String(),
      'box': box,
      'due': due.toUtc().toIso8601String(),
      'lapses': lapses,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is LostWord &&
      other.word == word &&
      other.note == note &&
      other.addedAt.isAtSameMomentAs(addedAt) &&
      other.box == box &&
      other.due.isAtSameMomentAs(due) &&
      other.lapses == lapses;

  @override
  int get hashCode => Object.hash(
    word,
    note,
    addedAt.millisecondsSinceEpoch,
    box,
    due.millisecondsSinceEpoch,
    lapses,
  );

  @override
  String toString() =>
      'LostWord($word, box $box, due ${due.toIso8601String()}, lapses $lapses)';

  static DateTime _parseDate(String value, String field) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('LostWord.$field is not a date: $value');
    }
    return parsed.toLocal();
  }
}
