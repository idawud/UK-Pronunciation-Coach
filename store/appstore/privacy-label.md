# App Store Connect: App Privacy answers

App Privacy > "Do you or your third-party partners collect data from this app?"
Answer **No**. App Store Connect then shows the label **Data Not Collected**.

Why this is accurate

- Audio is processed on the device only and never transmitted.
- No analytics, advertising, attribution or crash-reporting SDKs
  (`tools/ci/check_licences.py` and `pubspec.yaml` keep it that way).
- "Send feedback" hands a draft to the Mail app; the user sends it, not the app.
- The only request is the optional model download from GitHub, which sends no user data.

Related settings

- `ios/Runner/PrivacyInfo.xcprivacy` declares no tracking, no collected data types, and
  the required-reason API entries the app uses.
- `NSMicrophoneUsageDescription`: "The microphone records you reading aloud so the app can
  score your pronunciation. Recordings stay on your phone and are never uploaded."
- Export compliance: uses only standard HTTPS (exempt); `ITSAppUsesNonExemptEncryption`
  is not set in Info.plist, so answer the export-compliance questions in App Store Connect (standard encryption only, exempt).
- Age rating: 4+. Category: Education. Secondary: Reference.
- Privacy policy URL: required; use the hosted `store/privacy-policy.md`.
- TestFlight: external testers need Beta App Review; give it the beta notes from
  `docs/release.md`.
