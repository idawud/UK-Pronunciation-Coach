# Store listing text (British English)

App name: **UK Pronunciation Coach** (30 characters max on both stores; this is 23)

## Short description (Google Play, 80 characters max)

Read aloud, see which words to fix, and practise British English. Works offline.

(80 characters)

## Subtitle (App Store, 30 characters max)

British English, offline

(24 characters)

## Promotional text (App Store, 170 characters max)

Read a short passage aloud and see how close you sound to Standard Southern British English. Wrong words are highlighted, then drilled. Private by design.

## Full description (Play 4000 / App Store 4000 characters max)

Want to sound clearer in British English? UK Pronunciation Coach listens while you read a short passage aloud, scores how close you are to Standard Southern British English, and shows you exactly which words to work on.

How it works
- Pick a passage at your level. There are twenty at each level.
- Tap record and read it aloud.
- In a couple of seconds you get an overall score, an accuracy score and a fluency score, with every word marked good, close or needs fixing.
- Tap a word to hear a British voice say it, see the sounds you missed, and get a short tip.
- Drill the tricky words until they land, then read the passage again and watch your score climb.
- Track your streak and progress over time, and set an optional daily reminder.

Private and offline
- The speech models run on your phone. Your voice is never uploaded.
- No account, no adverts, no analytics, no tracking.
- Works without a connection once installed. A larger, more accurate model is an optional download, and you choose when to fetch it.
- Delete all your data at any time from Settings.

Honest about what it is
The app compares your sounds with a British English reference. It is a practice aid, not an examiner, and scores are a guide. In this early version it catches clear mispronunciations but misses many subtle ones, and it accepts a few American sounds as correct. It works best in a quiet room with the phone held at a normal reading distance. It is built for learners of English; it does not teach other accents.

Free and built with open-source speech models. Licences are listed in the app under Settings.

Questions or ideas? Use Settings > Send feedback. It opens an email draft in your own mail app; nothing is sent unless you send it.

## Keywords (App Store, 100 characters max)

pronunciation,british,english,accent,speaking,IPA,phonetics,learn,read aloud,ESL,offline

## What's new (1.0.0)

First release.

## Beta notes (TestFlight / Play internal testing)

Paste this into the TestFlight "Test Information / What to Test" box and the Play internal
testing release notes.

Thanks for testing. Please practise a few times a week for four weeks, re-read some passages,
and tell us what felt wrong.

What to expect in this beta
- The app reliably flags clear mispronunciations, for example "think" said as "tink". It misses
  many subtler ones: on our test set it caught roughly 3 in 10 of the mistakes we put in. Vowel
  errors, z/s, dropped h and wrong word stress are the weakest areas.
- The speech model was trained mainly on American English labels, so a few American
  pronunciations are accepted as correct: the "hot" vowel, and sounding the r in words like "car".
- It rarely marks correct British speech as wrong: about 2% of correct words in our
  measurement on native British speakers (full model; the smaller bundled model is less
  careful, about 6%). A red word is therefore worth a look, but a green word is not proof
  that you said it right.
- Everything runs on your phone. No recordings leave the device.

The feedback that helps most
1. Words you said wrongly (or knew you were unsure of) that the app marked green.
2. Words you said correctly that the app marked red.
Settings > Send feedback opens an email draft; give the passage and the word, and attach your
progress file if you want to. The app never sends anything by itself.

(Source of the figures: `docs/eval-report.md`. Update this block when the numbers change.)

## Screenshot plan

Four screens, in this order, light theme (dark variants optional), seeded sample data, no real names.

1. Home: today's passage and streak. Caption: "Read aloud, get scored"
2. Read: a passage with the record button. Caption: "Read a passage at your level"
3. Results: scores with good, close and fix words marked. Caption: "See exactly which words to fix"
4. Progress: the score chart. Caption: "Watch your accent improve"

Sizes: iPhone 6.9" (1320x2868) and 6.5" (1284x2778), iPad 13" (2064x2752), Play phone
(1080x1920 or larger), Play 7" and 10" tablet. Generate them with
`STORE_SCREENSHOTS=1 flutter test test/store/store_screenshots_test.dart` (writes
`store/screenshots/<device>/`, see docs/release.md). Add captions in the store consoles or a design tool.
Play also needs the 512x512 icon (`store/icon/play-icon-512.png`) and the 1024x500 feature graphic
(`store/play/feature-graphic.png`, made by `python -m tools.release.feature_graphic`).
