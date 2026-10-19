// Read screen goldens (U2-read): main states, light + dark, phone + tablet.
// Update on Linux only:  flutter test --update-goldens --tags golden
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:uk_pronunciation_coach/core/contracts/navigation.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';
import 'package:uk_pronunciation_coach/ui/read/read_screen.dart';
import 'package:uk_pronunciation_coach/ui/read/read_state.dart';
import 'package:uk_pronunciation_coach/ui/theme/app_theme.dart';

import '../../helpers/golden.dart';

final _content = ReadContent(
  mode: ReadMode.passage,
  passage: riverPassage,
  target: riverPassage,
  passageNumber: 4,
  passageCount: 20,
);

final _levels = [
  for (var i = 0; i < 64; i++) 0.15 + 0.7 * ((i * 37) % 23) / 23,
];

final Map<String, ReadState> _states = {
  'idle': ReadState(content: _content, phase: const ReadIdle()),
  'recording': ReadState(
    content: _content,
    phase: ReadRecording(elapsed: const Duration(seconds: 12), levels: _levels),
  ),
  'scoring': ReadState(
    content: _content,
    phase: const ReadScoring(stage: ScoringStage.recognising, progress: 0.45),
  ),
  'permission denied': ReadState(
    content: _content,
    phase: const ReadPermissionDenied(permanently: true),
  ),
  'too noisy': ReadState(
    content: _content,
    phase: const ReadRetryNeeded(RetryReason.tooNoisy),
  ),
  'model downloading': ReadState(
    content: _content,
    phase: const ReadIdle(),
    downloadNotice: const ModelDownloadProgress(
      state: DownloadState.downloading,
      receivedBytes: 42,
      totalBytes: 100,
    ),
  ),
};

/// The Read screen frame around a fixed [state] (no providers needed).
class _Frame extends StatelessWidget {
  const _Frame({required this.state, required this.theme});

  final ReadState state;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(state.content!.passage.title),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.text_decrease),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.text_increase),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 600;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxReadingWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 32 : 16,
                      vertical: wide ? 24 : 12,
                    ),
                    child: ReadBody(state: state),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

GoldenTestGroup _group(Size size, List<String> names) => GoldenTestGroup(
  columns: names.length,
  children: [
    for (final (themeName, theme) in [
      ('light', withTestFonts(AppTheme.light())),
      ('dark', withTestFonts(AppTheme.dark())),
    ])
      for (final name in names)
        GoldenTestScenario(
          name: '$name $themeName',
          child: SizedBox.fromSize(
            size: size,
            child: _Frame(state: _states[name]!, theme: theme),
          ),
        ),
  ],
);

void main() {
  goldenTest(
    'Read screen on a phone',
    fileName: 'read_screen_phone',
    builder: () => _group(goldenPhoneSize, _states.keys.toList()),
  );

  goldenTest(
    'Read screen on a tablet',
    fileName: 'read_screen_tablet',
    builder: () => _group(goldenTabletSize, ['idle', 'recording', 'scoring']),
  );
}
