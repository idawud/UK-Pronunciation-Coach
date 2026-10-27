# Installing UK Pronunciation Coach on an Android phone

How to get the app onto your own Android phone once the v1 features are built. There
are three ways. Pick the first one that's available to you.

| Way | When it works | Updates |
| --- | --- | --- |
| A. Google Play internal testing | After the release work (R1) sets up the Play beta track | Automatic, through the Play Store |
| B. APK from a GitHub Release | After R1's `release.yml` publishes a tagged release | Install the new APK over the old one |
| C. Build from source over USB | Any time, on a computer with the Flutter and Android tools | Rebuild and reinstall |

> **Beta accuracy.** The app reliably flags clear mispronunciations but misses many subtler
> ones, and accepts a few American sounds as correct. Details: "What to expect in this beta" in
> `store/listing.md`.

## Before you start

- **Phone:** Android 10 or newer (the app's minimum), ideally with 4 GB of RAM or more.
  Older or low-memory phones work with the built-in light model, which gives word
  scores only.
- **Space:** about 150 MB for the app, plus about 360 MB if you later download the
  optional full model.
- **A British voice for "Play British":** open **Settings > System > Languages > Text-to-speech
  output**, tap the settings icon next to your speech engine (usually Speech Services by
  Google), choose **Install voice data**, and install **English (United Kingdom)**. The
  app's onboarding checks this for you and shows the same steps.

## A. Google Play internal testing (easiest)

1. Send the owner of the Play Console listing the Google account you use on your phone,
   so they can add you to the internal testing list.
2. Open the opt-in link they send you on your phone and tap **Become a tester**.
3. Follow the **Download it on Google Play** link and install the app as usual.

Updates arrive through the Play Store like any other app.

## B. APK from a GitHub Release

1. On your phone, open the repository's **Releases** page on GitHub and download the
   latest `.apk` file from the release's **Assets** (pick the `arm64-v8a` one if
   there are several: almost every phone from the last few years uses it).
2. Open the downloaded file. If Android asks, allow your browser or file manager to
   **Install unknown apps** (Settings > Apps > Special app access > Install unknown apps).
3. Tap **Install**. If Play Protect warns that the app is from an unknown developer, choose
   **Install anyway**. The app is signed by this project, not by Google Play.

To update, install the newer APK over the old one. Your progress is kept as long as both
APKs are signed with the same key.

## C. Build from source and install over USB

### On the computer

You need:

- Flutter (the version pinned in `.github/workflows/ci.yml`, `FLUTTER_VERSION`)
- Java 17 and the Android SDK (easiest via Android Studio), with platform 37 installed:
  the app compiles against Android SDK 37
- Python 3, to fetch the model files

```bash
git clone https://github.com/idawud/UK-Pronunciation-Coach.git
cd UK-Pronunciation-Coach
flutter pub get

# Download the bundled (light) model into assets/models/ and check its SHA-256.
python3 tools/ci/fetch_models.py --tier light

# Release build, one APK per CPU type (smaller than a universal APK).
flutter build apk --release --split-per-abi
```

The APK for most phones is `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

Release builds are signed with the project's release key when it's configured
(the release work, R1, documents this in `docs/release.md`). Without it, build with `flutter build apk --debug` instead.
That gives a debug-signed APK that installs the same way but is larger and slower.

### On the phone

1. Open **Settings > About phone** and tap **Build number** seven times to turn on
   Developer options.
2. Open **Settings > System > Developer options** and turn on **USB debugging**.
3. Connect the phone with a USB cable and accept the **Allow USB debugging?** prompt.

### Install

```bash
adb devices          # your phone should be listed as "device"
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Or run `flutter install` to build and install in one step. You can also copy the APK to
the phone and open it there, as in way B.

## First run on the phone

1. **Welcome**, then allow the **microphone**. Recordings stay on the phone and are
   deleted after scoring unless you turn on "Keep recordings".
2. **British voice check:** if no English (UK) voice is installed, follow the steps
   on screen (same as *Before you start*), then tap **Check again**.
3. **Placement:** read three short passages. The app picks your starting level from them.
   This takes about two minutes.
4. Optional, for scores on every sound: **Settings > Scoring model > Full**, then download
   the full model (about 360 MB) over Wi-Fi. After that the app needs no internet at all.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| "App not installed" or "package conflicts with an existing package" | An APK signed with a different key is already installed (for example a debug build). Uninstall the old app first. This deletes its progress, so use **Settings > Export progress** beforehand and **Import progress** afterwards |
| "There was a problem parsing the package" | The phone runs Android 9 or older, or the APK is for another CPU type. Use Android 10+ and the `arm64-v8a` APK (or `armeabi-v7a` on very old 32-bit phones) |
| Play British is silent, or the app says no British voice was found | Install the English (United Kingdom) voice data (see *Before you start*), then **Settings > British voice > Check again** |
| Recording doesn't start | Allow the microphone: **Settings > Apps > UK Pronunciation Coach > Permissions > Microphone** |
| "Too quiet" or "Too noisy" after reading | Hold the phone 20–30 cm from your mouth and move somewhere quieter |
| Scoring takes a long time | Switch to the light model in **Settings > Scoring model**. It's faster on older phones |
| `adb devices` shows "unauthorized" | Unplug, plug back in, and accept the USB debugging prompt on the phone |

## Testing a build before release

Every pull request and push to `main` builds a debug APK in CI. Open the run in the
repository's **Actions** tab and download the `app-debug-apk` artifact from the
**build-android** job. Install it as in way B.

Until model files are published (see `docs/models.md`), these builds have no bundled
light model and can't download the full one, so scoring doesn't work in them yet.
