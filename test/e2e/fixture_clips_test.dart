import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/engine/audio/wav.dart';

import 'make_fixture_clips.dart';

void main() {
  test('the device copy of the e2e clips is up to date', () {
    expect(
      File(outFile).readAsStringSync(),
      fixtureClipsSource(),
      reason: 'run: dart run test/e2e/make_fixture_clips.dart',
    );
  });

  test('every e2e clip is 16 kHz mono speech with a quiet tail', () {
    for (final f in Directory(clipsDir).listSync().whereType<File>()) {
      if (!f.path.endsWith('.wav')) continue;
      final audio = decodeWav(f.readAsBytesSync());
      expect(audio.sampleRate, 16000, reason: f.path);
      expect(audio.samples.length, greaterThan(16000 * 2), reason: f.path);
    }
  });
}
