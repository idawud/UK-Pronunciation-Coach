# Release runbook (R1-release)

Nothing here has been run: the author had no Android SDK, Xcode or working GitHub Actions
(billing block). Everything is written to work on CI or a developer machine; do the
first release as a dry run (see "Dry run").

## What a release is

Push a tag `vX.Y.Z` (or `vX.Y.Z-beta.N`, which becomes a pre-release) on a commit of `main`.
`.github/workflows/release.yml` then:

1. runs the whole `ci.yml` (called as a reusable workflow);
2. checks the tag matches `version:` in `pubspec.yaml` and that `integration.yml` has a
   green run on that exact commit (it runs on every push to main; for any other commit run it
   with "Run workflow");
3. builds on Ubuntu: signed AAB plus split-per-ABI APKs; on macOS: signed IPA. Both fetch the
   bundled light model from the `models-v1` release;
4. runs `tools/release/app_size.py` on the results (fails above 150 MB for the arm64 APK and IPA);
5. creates a **draft** GitHub Release with the files and `SHA256SUMS.txt`. Publish it by hand;
6. only when the repository variable `UPLOAD_TO_STORES` is `true`: fastlane uploads the AAB to
   Play **internal testing** (as a draft) and the IPA to **TestFlight**.

## Before the first tag

- [ ] `models-v1` GitHub Release exists with the model assets and `assets/models/manifest.json`
  holds their real URLs and SHA-256 values (`docs/models.md`, "Publishing"). Without it
  `tools/ci/fetch_models.py` fails, so ci.yml and the builds fail. The light model (about
  95 MB) is bundled; the full model (about 355 MB) stays an optional in-app download.
- [ ] `integration.yml` is green on `main`.
- [ ] Bundle id `uk.pronunciationcoach.uk_pronunciation_coach` (Android) and
  `uk.pronunciationcoach.ukPronunciationCoach` (iOS) are registered in Play Console and
  App Store Connect (change them in `android/app/build.gradle.kts`, the Xcode project and
  `ios/ExportOptions.plist.template` together if yours differ).
- [ ] Store listing, data safety, privacy label, privacy policy URL: `store/`. The policy URL is
  <https://idawud.github.io/UK-Pronunciation-Coach/privacy/> (see "Privacy policy hosting").
- [ ] Bump `version:` in `pubspec.yaml` (`1.0.0+1`; the number after `+` is the build number and
  must rise on every upload to either store).

## Secrets and variables

Add under Settings > Secrets and variables > Actions. Never commit any of these.

| Name | Kind | Used for |
| --- | --- | --- |
| `ANDROID_KEYSTORE_BASE64` | secret | upload keystore, `base64 -w0 upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | secret | keystore password |
| `ANDROID_KEY_ALIAS` | secret | key alias |
| `ANDROID_KEY_PASSWORD` | secret | key password |
| `IOS_CERTIFICATE_BASE64` | secret | Apple Distribution certificate as `.p12`, `base64 -i dist.p12` |
| `IOS_CERTIFICATE_PASSWORD` | secret | the `.p12` password |
| `IOS_PROVISIONING_PROFILE_BASE64` | secret | App Store provisioning profile, `base64 -i x.mobileprovision` |
| `IOS_PROFILE_NAME` | secret | the profile's name as shown in the developer portal |
| `IOS_TEAM_ID` | secret | 10-character Apple team id |
| `PLAY_SERVICE_ACCOUNT_JSON` | secret | Play API service account JSON (only for upload) |
| `APPSTORE_API_KEY_ID`, `APPSTORE_API_ISSUER_ID`, `APPSTORE_API_KEY_P8` | secrets | App Store Connect API key (only for upload) |
| `FEEDBACK_EMAIL` | variable | address behind Settings > Send feedback (`--dart-define=FEEDBACK_EMAIL=...`). Unset, the app shows a placeholder address, so set it before any beta |
| `UPLOAD_TO_STORES` | variable | `true` turns on the fastlane jobs; unset by default |

`GITHUB_TOKEN` is supplied by Actions (`contents: write` for the release job only).

### Creating the Android upload key (on your machine)

```bash
keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 upload.jks   # paste into ANDROID_KEYSTORE_BASE64
```

Keep `upload.jks` and its passwords in a password manager, not in the repo (`*.jks` and
`android/key.properties` are git-ignored). Enrol in Play App Signing so a lost upload key can
be reset.

## Building by hand

```bash
# Android: create android/key.properties (git-ignored) with storeFile, storePassword, keyAlias, keyPassword
python3 tools/ci/fetch_models.py --tier light --cache .model-cache
flutter build appbundle --release --dart-define=FEEDBACK_EMAIL=you@example.com
flutter build apk --release --split-per-abi
# iOS (macOS): copy ios/Flutter/Signing.xcconfig.example to Signing.xcconfig and
# ios/ExportOptions.plist.template to ExportOptions.plist, edit both
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
python3 -m tools.release.app_size build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Without signing configured, local release builds use the debug key (they run, but cannot go to
Play). CI sets `REQUIRE_RELEASE_SIGNING=true`, so a missing secret fails the build.

## App size

SPEC target: download under 150 MB with the light model bundled. Estimate (not measured):
light model about 95 MB, native ONNX runtime and sherpa libraries about 20-40 MB per ABI,
Flutter engine, content and voices the rest, so roughly 130-150 MB for an arm64 APK; the AAB
download per device is similar. This is tight. `app_size.py` prints the breakdown; if the
limit is hit, check that only needed ABIs ship and that R8 shrinking is on (it is for release).

## Screenshots

`STORE_SCREENSHOTS=1 flutter test test/store/store_screenshots_test.dart` renders Home, Read,
Results and Progress with seeded data into `store/screenshots/<device>/` (git-ignored output).
Linux only. Captions and the plan are in `store/listing.md`. The Play 1024x500 feature graphic is
`store/play/feature-graphic.png`, made by `python -m tools.release.feature_graphic` (`--check` in pytest).

## Dry run (do this first)

1. In a fork or a scratch repo with secrets of a throw-away keystore, push `v0.0.1-beta.1`.
2. Confirm: checks pass, gate passes, the artifacts install (`adb install` the arm64 APK; the
   debug-signed fallback must not appear in release.yml output), the draft release lists the files.
3. Delete the draft and the tag.

## Privacy policy hosting

`store/privacy-policy.md` is the only copy. `.github/workflows/pages.yml` runs
`python -m tools.release.site` (plain HTML, no scripts, fonts or trackers) and deploys it to
GitHub Pages whenever the policy changes on `main`, or by hand with "Run workflow".
URL for both store consoles: **https://idawud.github.io/UK-Pronunciation-Coach/privacy/**
(also in `store/appstore/privacy-label.md` and `store/play/data-safety.md`).

The one owner setting: repository **Settings > Pages > Build and deployment > Source: GitHub
Actions**. Nothing publishes until that is set (the deploy job fails harmlessly before it).
Then run the `pages` workflow once and open the URL to check it.

## Beta (30-50 learners, 4 weeks)

### What testers are told (accuracy limits)

The beta ships on the current models, with the limits stated plainly. The block to paste is
"What to expect in this beta" in `store/listing.md`; the README repeats it briefly. Facts, all
from `docs/eval-report.md` (held-out data, full tier unless stated):

- Clear mispronunciations are flagged reliably. Roughly 3 in 10 injected errors are caught
  (29.5% red; consonant substitutions 45.7%, vowel substitutions 25.8%, stress 13.9%, added or
  dropped h 5% to 7%). Weak spots: vowels, z/s, dropped h, word stress.
- The phoneme model was trained mainly on American (eSpeak en-us) labels, so some American
  forms pass: the "hot" vowel and the r in "car".
- False red on correct native British speech: 2.5% of all 2,135 VCTK words (3.5% on the held-out
  speakers; 1.7% with accepted alternative pronunciations, the way the app scores).
  **The bundled light model is worse: about 5.9% on the same speakers** (held-out 6.6%), and
  its recall is lower. Testers who download the full model (Settings) get the figures above.
- Everything runs on the phone; no recordings leave it.

Update the block in `store/listing.md` if these numbers change. Not yet measured: accuracy
on real learner speech (no teacher labels), and speed on real phones.



Goal: check the SPEC success metrics: 40% of learners practising 3+ days a week and +10 points
on repeated passages over 4 weeks (word agreement with teacher labels is I2's job).

1. **Recruit** 30-50 learners of English who want British English (language-school students, a
   community group, friends of friends). Aim for a mix of Android and iPhone, phones and tablets.
2. **Distribute.** Play Console > Testing > Internal testing (up to 100 testers, by email list)
   and TestFlight internal/external groups (external needs Beta App Review, so allow a few days). Android users
   may instead install the APK from the GitHub Release (`docs/install-android.md`).
3. **Brief** (use the beta notes in `store/listing.md`, which include "What to expect in this
   beta"): practise at least 3 days a week for 4 weeks, re-read passages, try the drills, and use
   Settings > Send feedback for problems. Ask specifically for (a) words they said wrongly that
   the app marked green and (b) words they said correctly that it marked red, with the passage
   and word. Both feed the next calibration and the British fine-tune.
   Tell them plainly that nothing is collected and that sending feedback and the progress file
   is their choice.
4. **Collect.** Weekly reminder email. Testers who agree use Settings > Send feedback; attach
   the progress file (same file as Export progress) to the draft and send it. Keep the files in a private
   folder, one per learner, named by a code, not by name. Delete them after the report.
5. **Report** at week 4:

   ```bash
   python -m tools.beta.report progress/*.json                # human table
   python -m tools.beta.report --json beta.json progress/*.json
   python -m tools.beta.report --strict progress/*.json       # exit 1 if a target is missed
   ```

   It reports practice days per week per learner, the share at 3+, and the mean score gain on
   repeated passages, against the SPEC targets. Only testers who send a file are counted, so
   this over-represents engaged learners; say so in the write-up.
6. **Decide.** Fix blockers from feedback, bump the build number, tag again. When targets and
   reviewer feedback are fine, promote the Play internal build to production and submit the
   TestFlight build for App Review.

## Owner-only beta checklist (in order)

Everything below needs your accounts or machine; none of it was done by an agent.

1. [ ] Set `FEEDBACK_EMAIL` (repository variable) or confirm the built-in default address is
   the one you want to receive feedback.
2. [x] ~~Publish the `models-v1` release and real URLs/SHA-256 in
   `assets/models/manifest.json`~~ — done on 2026-10-27. Published (not a pre-release) at
   [idawud/UK-Pronunciation-Coach-models](https://github.com/idawud/UK-Pronunciation-Coach-models/releases/tag/models-v1);
   the real URLs and checksums are already committed in the manifest.
3. [ ] Create the Android upload keystore (`keytool` command above); store it and its passwords
   in a password manager.
4. [ ] Add the GitHub secrets and variables from the table above (Android four first; iOS five;
   upload secrets and `UPLOAD_TO_STORES` only when you want fastlane uploads).
5. [ ] Turn on Pages: Settings > Pages > Source: GitHub Actions. Run the `pages` workflow and
   open the privacy-policy URL.
6. [ ] Register the bundle ids in Play Console and App Store Connect; paste the privacy-policy
   URL, the data-safety and privacy-label answers from `store/`, the listing text, screenshots
   and `store/play/feature-graphic.png`.
7. [ ] Create the Play **internal testing** track and a **TestFlight** group (external group
   needs Beta App Review; allow a few days).
8. [ ] Dry run with `v0.0.1-beta.1` on a scratch repo (see "Dry run"), then delete it.
9. [ ] Confirm `integration.yml` is green on `main` and `version:` in `pubspec.yaml` is `1.0.0+1`.
10. [ ] Tag `v1.0.0` on that commit of `main`; check the draft GitHub Release and the uploaded
    builds, then publish the draft yourself.
11. [ ] Invite 30-50 testers (Play email list; TestFlight invitations) with the "What to expect
    in this beta" text.
12. [ ] After four weeks, run `tools/beta/report` and decide (step 6 of the plan above).

## Rollback

Release assets are immutable per tag: ship a new tag with a higher build number. Halt a Play
rollout from the Console; pull a build from sale in App Store Connect.
