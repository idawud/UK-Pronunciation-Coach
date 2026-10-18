// Checks the committed fixtures: JSON matches lib/core/fakes/sample_data.dart
// (regenerate with `dart run scripts/generate_fixtures.dart`) and every WAV is
// 16 kHz mono 16-bit PCM as described in audio/manifest.json.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/core/fakes/sample_data.dart';
import 'package:uk_pronunciation_coach/core/models/models.dart';

Object? _load(String path) =>
    jsonDecode(File('test/fixtures/$path').readAsStringSync());

void main() {
  test('passages, posteriors and results match the sample data', () {
    final passages = [
      for (final p in _load('passages/sample_passages.json')! as List<dynamic>)
        Passage.fromJson(p as Map<String, dynamic>),
    ];
    expect(passages, samplePassages);
    expect(
      PhonemePosteriors.fromJson(
        _load('posteriors/river_canned.json')! as Map<String, dynamic>,
      ),
      riverPosteriors,
    );
    expect(
      PhonemePosteriors.fromJson(
        _load('posteriors/tea_perfect.json')! as Map<String, dynamic>,
      ),
      syntheticPosteriors(teaPassage),
    );
    expect(
      AttemptResult.fromJson(
        _load('results/river_canned_attempt.json')! as Map<String, dynamic>,
      ),
      cannedRiverAttempt,
    );
  });

  test('WAV fixtures are 16 kHz mono 16-bit and match the manifest', () {
    final manifest = _load('audio/manifest.json')! as Map<String, dynamic>;
    expect(manifest.keys, containsAll(['clean_read.wav', 'silence.wav']));
    for (final MapEntry(key: name, value: meta) in manifest.entries) {
      final bytes = File('test/fixtures/audio/$name').readAsBytesSync();
      final h = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF', reason: name);
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(h.getUint16(20, Endian.little), 1, reason: 'PCM');
      expect(h.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(h.getUint32(24, Endian.little), 16000);
      expect(h.getUint16(34, Endian.little), 16);
      final dataBytes = h.getUint32(40, Endian.little);
      final ms = dataBytes ~/ 2 * 1000 ~/ 16000;
      final info = meta as Map<String, dynamic>;
      expect(ms, info['durationMs'], reason: name);
      expect(
        AudioQuality.values.map((q) => q.name),
        contains(info['expectedQuality']),
      );
    }
  });
}
