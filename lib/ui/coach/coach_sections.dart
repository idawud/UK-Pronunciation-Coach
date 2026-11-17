import 'package:flutter/material.dart';

import 'coach_routes.dart';
import 'confusions/confusions_screen.dart';
import 'describe/describe_screen.dart';
import 'record/record_compare_screen.dart';
import 'sounds/sounds_screen.dart';
import 'words/words_screen.dart';

/// One card on the Coach hub and one sub-route under [coachPath].
class CoachSection {
  /// Creates a section. [id] is the relative route segment, so the full path is
  /// `$coachPath/$id`; [subPath] must equal that full path.
  const CoachSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.subPath,
    required this.builder,
  });

  /// Relative route segment, e.g. `sounds`.
  final String id;

  /// Card title.
  final String title;

  /// Card subtitle.
  final String subtitle;

  /// Card icon.
  final IconData icon;

  /// Full route path, e.g. `/coach/sounds`. The hub pushes it.
  final String subPath;

  /// Builds the section's screen.
  final WidgetBuilder builder;
}

/// The Coach hub sections, in display order. To build a section, overwrite only its
/// stub screen file; keep the entries here as they are.
final coachSections = <CoachSection>[
  CoachSection(
    id: 'sounds',
    title: 'Sounds',
    subtitle: 'Weak sounds, minimal pairs and the exercise library',
    icon: Icons.graphic_eq,
    subPath: coachSoundsPath,
    builder: (_) => const SoundsScreen(),
  ),
  CoachSection(
    id: 'confusions',
    title: 'Confusions',
    subtitle: 'My confusions & daily session',
    icon: Icons.compare_arrows,
    subPath: coachConfusionsPath,
    builder: (_) => const ConfusionsScreen(),
  ),
  CoachSection(
    id: 'words',
    title: 'Words',
    subtitle: 'Lost-word bank',
    icon: Icons.bookmark_border,
    subPath: coachWordsPath,
    builder: (_) => const WordsScreen(),
  ),
  CoachSection(
    id: 'record',
    title: 'Record & compare',
    subtitle: 'Record & compare',
    icon: Icons.mic_none,
    subPath: coachRecordPath,
    builder: (_) => const RecordCompareScreen(),
  ),
  CoachSection(
    id: 'describe',
    title: 'Describe it',
    subtitle: 'Describe it & phrases',
    icon: Icons.chat_bubble_outline,
    subPath: coachDescribePath,
    builder: (_) => const DescribeScreen(),
  ),
];
