# Handoff: R1-release (Wave 3)

Nothing was built, signed or published: no Android SDK, Java or Xcode here, and GitHub Actions is
blocked by billing. All of it is untested on CI/devices. Start with the dry run in `docs/release.md`.

## Built

- **App identity**: icon (`store/icon/`, generator in `tools/release`), splash screens, name,
  version 1.0.0+1.
- **Android** (`android/app/build.gradle.kts`): release signing from `android/key.properties`
  (git-ignored) or env vars; `REQUIRE_RELEASE_SIGNING=true` fails the build if missing; R8 shrinking.
- **iOS**: manual signing via git-ignored `ios/Flutter/Signing.xcconfig`, `ExportOptions.plist.template`,
  `PrivacyInfo.xcprivacy` (no tracking, no data), microphone text saying recordings stay on the phone.
- **Send feedback** (Settings): `lib/ui/settings/feedback.dart`, url_launcher (BSD) email draft; the
  user may save and attach their progress file; no upload. Address from
  `--dart-define=FEEDBACK_EMAIL=...`, placeholder default (release.yml passes the `FEEDBACK_EMAIL` variable).
- **Licences page** complete against `docs/licences.md`.
- **tools/beta/report.py** (+ pytest): practice days per week and gains on repeated passages vs the
  SPEC targets (40% at 3+ days; +10 over 4 weeks); `--strict`, `--json`.
- **tools/release/app_size.py** (+ pytest): size breakdown, fails above 150 MB.
- **store/**: `play/data-safety.md` (nothing collected or shared), `appstore/privacy-label.md`
  (Data Not Collected), `privacy-policy.md` (draft to host), `listing.md` (short, full, keywords,
  beta notes, screenshot plan); `test/store/store_screenshots_test.dart` renders the four screens
  (`STORE_SCREENSHOTS=1`, skipped otherwise).
- **.github/workflows/release.yml** on tag `v*`: calls ci.yml, gate for tag = pubspec version and a
  green integration.yml run on the commit, signed AAB/APKs on Ubuntu, signed IPA on macOS, draft
  GitHub Release with `SHA256SUMS.txt`, optional fastlane to Play internal and TestFlight (only if
  variable `UPLOAD_TO_STORES` is `true`). YAML parses; actions not run.
- **docs/release.md**: runbook, every secret, models-v1 dependency, dry run, 30-50 learner beta plan.

## Files outside my folders

`.github/workflows/ci.yml` (one line: `workflow_call:` trigger), `.gitignore` (store/screenshots/),
`pubspec.yaml`, `pubspec.lock` (url_launcher), `docs/licences.md` (new package rows),
`lib/ui/settings/{feedback,settings_screen,licences_screen,licence_data,bundled_licences,local_notifications_reminder_scheduler}.dart`,
`test/ui/settings/{feedback,licences_screen,local_notifications_reminder_scheduler}_test.dart`,
`test/ui/goldens/goldens/{ci,linux}/settings_phone.png` (regenerated: new Settings row),
`test/store/store_screenshots_test.dart`.

## Known gaps

- Nothing built or run on a device; Gradle/Xcode config, workflow and fastlane commands are unverified.
- Play feature graphic (1024x500) not designed; screenshots not generated or captioned.
- Privacy policy needs a public URL and a real contact address.
- `models-v1` release must exist with real manifest URLs or every build fails at the model fetch.
- Size is estimated at about 130-150 MB (tight), not measured.
- Beta report counts only learners who choose to send a file.
