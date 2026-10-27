# Building the app on Windows and running it on your Android phone

For developing on a Windows PC with the phone plugged in over USB. If you only want to
*install* a finished build, see `install-android.md` instead.

**Build on the Windows side, not inside WSL.** WSL has no USB access by default, so
`adb` cannot see a phone plugged into the PC. Keep a Windows checkout of the repository
for building and running on the phone. (WSL is fine for tests and the Python tools; only
the phone build needs Windows.)

## What you need

| | Version | Why |
| --- | --- | --- |
| Flutter SDK | 3.47.7 | the version CI uses, so local builds match |
| JDK | 17 | Gradle |
| Android SDK | platform 37, build-tools 37, platform-tools | the app compiles against SDK 37 |
| Python | 3.9+ | downloads the bundled speech model |
| Phone | Android 10 or newer | the app's minimum (minSdk 29) |

About 15 GB of disk, most of it Android Studio and the Gradle caches.

## 1. Set up the PC (once)

Open **PowerShell** and clone the repository somewhere with a short, space-free path:

```powershell
git clone https://github.com/idawud/UK-Pronunciation-Coach.git C:\src\coach
cd C:\src\coach
powershell -ExecutionPolicy Bypass -File scripts\windows\setup.ps1
```

The script installs Git, Temurin JDK 17, Python, the pinned Flutter SDK and Android
Studio, adds them to your PATH, installs the Android SDK packages and accepts the SDK
licences. It is safe to run again, and skips anything already installed.

The first time, it stops after installing Android Studio and asks you to open Android
Studio once so it can finish its own first-run setup, then run the script again.

When it finishes, **open a new terminal** so the PATH changes apply, and check:

```powershell
flutter doctor
```

"Android toolchain" and "Connected device" are the two lines that matter. Ignore
complaints about Visual Studio and Chrome unless you want desktop or web builds.

## 2. Set up the phone (once)

1. **Settings → About phone** → tap **Build number** seven times.
2. **Settings → System → Developer options** → turn on **USB debugging**.
3. Plug in the USB cable and accept the **Allow USB debugging?** prompt on the phone.
   Tick "Always allow from this computer".

Check the PC can see it:

```powershell
adb devices
```

Your phone should be listed as `device`. If it says `unauthorized`, unplug, plug back in
and accept the prompt. If nothing is listed, try a different cable: charge-only cables
are common and carry no data.

## 3. Build and run

```powershell
cd C:\src\coach
scripts\windows\run-on-phone.ps1
```

That fetches the bundled speech model (~90 MB, once), builds a debug build, installs it
and leaves it running with hot reload: press `r` to reload, `R` to restart, `q` to quit.

The first build takes several minutes, because Gradle downloads the Android NDK and
compiles the native speech runtime. Later builds take seconds.

To do it by hand instead:

```powershell
flutter pub get
python tools\ci\fetch_models.py --tier light --cache .model-cache
flutter run
```

## 4. Release build (optional)

A release build is smaller and much faster than a debug build, which matters here:
debug builds score speech noticeably more slowly. It needs a signing key.

Create `android\key.properties` (git-ignored, never commit it):

```properties
storeFile=C:\\Users\\you\\keys\\upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Then:

```powershell
scripts\windows\run-on-phone.ps1 -Release
```

See `release.md` for creating the key and for store releases.

## Useful commands

```powershell
flutter devices                 # what Flutter can see
flutter run -d <device-id>      # pick a phone when several are connected
flutter logs                    # the phone's log output
flutter clean                   # when a build goes strange
adb uninstall uk.pronunciationcoach.uk_pronunciation_coach
adb shell pm clear uk.pronunciationcoach.uk_pronunciation_coach   # wipe app data
```

Running over Wi-Fi instead of a cable (Android 11+):

```powershell
adb pair <phone-ip>:<port>      # Developer options > Wireless debugging > Pair device
adb connect <phone-ip>:<port>
```

## When something goes wrong

| Symptom | Fix |
| --- | --- |
| `flutter` or `adb` not recognised | Open a new terminal; PATH changes only apply to new ones |
| `adb devices` shows `unauthorized` | Re-accept the prompt on the phone; try another USB port |
| `adb devices` shows nothing | Charge-only cable, or missing phone USB driver (install your manufacturer's) |
| Gradle fails on long paths | Move the checkout somewhere short, like `C:\src\coach` |
| "requires Android SDK 37" | Re-run `setup.ps1`, or install platform 37 in Android Studio's SDK Manager |
| Build fails after switching branches | `flutter clean`, then build again |
| App installs but scoring does nothing | The model wasn't fetched: run `python tools\ci\fetch_models.py --tier light --cache .model-cache` |
| "App not installed" | A build signed with a different key is installed; uninstall it first (export your progress in Settings beforehand) |
| Antivirus slows builds to a crawl | Exclude the checkout and `%LOCALAPPDATA%\Pub\Cache` from real-time scanning |

## Running the tests

Tests do not need a phone and run on either Windows or WSL:

```powershell
flutter test
```

The full pre-push check (`scripts/check.sh`) is a bash script, so run that under WSL or
Git Bash.
