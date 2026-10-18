/// One-line pronunciation advice for common substitutions (A3), shown on Fix a word.
abstract interface class Tips {
  /// Advice when [expected] (IPA) was pronounced as [heard].
  ///
  /// - [heard] null or equal to [expected]: returns null (nothing to fix).
  /// - [heard] empty string: the sound was dropped; returns advice if known.
  /// - [heard] may hold more than one phoneme for insertions, e.g. expected `ɑː`,
  ///   heard `ɑːɹ` ("In British English, don't sound the r here").
  ///
  /// Returns null when no advice is known; never returns an empty string.
  String? tipFor(String expected, String? heard);
}
