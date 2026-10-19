import 'package:flutter_test/flutter_test.dart';
import 'package:uk_pronunciation_coach/voice/tts_engine.dart';
import 'package:uk_pronunciation_coach/voice/voice_selection.dart';

import 'helpers/fake_tts_engine.dart';

void main() {
  group('isBritish', () {
    for (final (locale, expected) in [
      ('en-GB', true),
      ('en_GB', true),
      ('EN-gb', true),
      ('en-GB-x-rp', true),
      ('eng-GBR', true),
      ('en-UK', true),
      ('en-US', false),
      ('en-AU', false),
      ('en', false),
      ('', false),
      ('cy-GB', false),
    ]) {
      test('$locale -> $expected', () {
        expect(VoiceSelection.isBritish(locale), expected);
      });
    }
  });

  group('isOffline', () {
    test('local voice is offline', () {
      expect(
        VoiceSelection.isOffline(androidVoice('en-gb-x-rjs-local')),
        isTrue,
      );
    });
    test(
      'network_required, -network, networkTts and notInstalled are excluded',
      () {
        expect(
          VoiceSelection.isOffline(androidVoice('a', network: true)),
          isFalse,
        );
        expect(
          VoiceSelection.isOffline(androidVoice('en-gb-x-rjs-network')),
          isFalse,
        );
        expect(
          VoiceSelection.isOffline(androidVoice('a', features: 'networkTts')),
          isFalse,
        );
        expect(
          VoiceSelection.isOffline(
            androidVoice('a', features: 'x\tnotInstalled'),
          ),
          isFalse,
        );
      },
    );
    test('embedded + network capable voice is offline', () {
      expect(
        VoiceSelection.isOffline(
          androidVoice('a', features: 'networkTts\tembeddedTts'),
        ),
        isTrue,
      );
    });
  });

  group('rank / best', () {
    test('no voices -> null', () {
      expect(VoiceSelection.best(const []), isNull);
    });

    test('only American voices -> null', () {
      expect(
        VoiceSelection.best([
          iosVoice('Samantha', locale: 'en-US', quality: 'enhanced'),
          androidVoice(
            'en-us-x-sfg-local',
            locale: 'en-US',
            quality: 'very high',
          ),
        ]),
        isNull,
      );
    });

    test('only network or not-installed en-GB voices -> null', () {
      expect(
        VoiceSelection.best([
          androidVoice(
            'en-gb-x-gba-network',
            quality: 'very high',
            network: true,
          ),
          androidVoice('en-gb-x-gbb-local', features: 'notInstalled'),
        ]),
        isNull,
      );
    });

    test('iOS: premium > enhanced > default > eloquence', () {
      final ranked = VoiceSelection.rank([
        iosVoice('Eddy', identifier: 'com.apple.eloquence.en-GB.Eddy'),
        iosVoice('Daniel'),
        iosVoice('Kate', quality: 'enhanced'),
        iosVoice('Samantha', locale: 'en-US', quality: 'premium'),
        iosVoice('Serena', quality: 'premium'),
      ]);
      expect(ranked.map((v) => v.name), ['Serena', 'Kate', 'Daniel', 'Eddy']);
    });

    test('iOS: legacy novelty voices rank below default', () {
      final ranked = VoiceSelection.rank([
        iosVoice('Old', identifier: 'com.apple.speech.synthesis.voice.old'),
        iosVoice('Arthur'),
      ]);
      expect(ranked.first.name, 'Arthur');
    });

    test('iOS: personal voice and nameless voices are excluded', () {
      expect(
        VoiceSelection.best([
          iosVoice('Me', identifier: 'com.apple.speech.personalvoice.123'),
          TtsVoice.fromMap({'locale': 'en-GB'}),
        ]),
        isNull,
      );
    });

    test('Android: quality, then latency, then name', () {
      final ranked = VoiceSelection.rank([
        androidVoice('en-gb-x-gbd-local', quality: 'high', latency: 'high'),
        androidVoice('en-gb-x-gbc-local', quality: 'high', latency: 'low'),
        androidVoice('en-gb-x-gbb-local', quality: 'high', latency: 'low'),
        androidVoice('en-gb-x-low-local', quality: 'low'),
        androidVoice('en-gb-x-vlo-local', quality: 'very low'),
        androidVoice('en-gb-x-unk-local', quality: 'unknown'),
        androidVoice('en-gb-x-nor-local', quality: 'normal'),
        androidVoice('en-gb-x-top-network', quality: 'very high'),
        androidVoice(
          'en-gb-x-top-local',
          quality: 'very high',
          latency: 'very high',
        ),
      ]);
      expect(ranked.map((v) => v.name), [
        'en-gb-x-top-local',
        'en-gb-x-gbb-local',
        'en-gb-x-gbc-local',
        'en-gb-x-gbd-local',
        'en-gb-x-nor-local',
        'en-gb-x-unk-local',
        'en-gb-x-low-local',
        'en-gb-x-vlo-local',
      ]);
    });

    test('Android latency order', () {
      final ranked = VoiceSelection.rank([
        for (final l in ['very high', 'high', 'normal', 'low', 'very low', '?'])
          androidVoice('v-$l', latency: l),
      ]);
      expect(ranked.map((v) => v.latency), [
        'very low',
        'low',
        '?',
        'normal',
        'high',
        'very high',
      ]);
    });
  });

  group('displayName', () {
    test('Android voice ids become readable', () {
      expect(
        VoiceSelection.displayName(androidVoice('en-gb-x-rjs-local')),
        'English (UK) RJS',
      );
      expect(
        VoiceSelection.displayName(androidVoice('en-GB-language')),
        'English (UK)',
      );
      expect(VoiceSelection.displayName(androidVoice('Brian')), 'Brian');
    });
    test('iOS quality suffix', () {
      expect(VoiceSelection.displayName(iosVoice('Daniel')), 'Daniel');
      expect(
        VoiceSelection.displayName(iosVoice('Kate', quality: 'enhanced')),
        'Kate (Enhanced)',
      );
      expect(
        VoiceSelection.displayName(iosVoice('Serena', quality: 'premium')),
        'Serena (Premium)',
      );
    });
  });

  test('TtsVoice.fromMap parses Android and iOS shapes', () {
    final a = androidVoice('n', features: 'a\tb', network: true);
    expect(a.features, ['a', 'b']);
    expect(a.networkRequired, isTrue);
    expect(a.raw['name'], 'n');
    final i = iosVoice('Daniel', quality: 'enhanced');
    expect(i.identifier, 'com.apple.voice.enhanced.en-GB.Daniel');
    expect(i.features, isEmpty);
    expect(i.toString(), contains('Daniel'));
    final empty = TtsVoice.fromMap({});
    expect(empty.name, '');
    expect(empty.locale, '');
    expect(empty.raw, isEmpty);
  });
}
