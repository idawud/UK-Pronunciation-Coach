<#
.SYNOPSIS
  Build UK Pronunciation Coach on Windows and run it on a connected Android phone.

.DESCRIPTION
  Fetches the bundled light model (about 90 MB, once), checks a phone is connected, then
  builds and installs. Run it from the repository root in a terminal where `flutter` and
  `adb` are on PATH (scripts\windows\setup.ps1 does that).

.PARAMETER Release
  Build a release APK instead of running the debug build. Needs android\key.properties.

.PARAMETER FeedbackEmail
  Address behind Settings > Send feedback. Defaults to the one built into the app.

.EXAMPLE
  scripts\windows\run-on-phone.ps1
  scripts\windows\run-on-phone.ps1 -Release
#>
[CmdletBinding()]
param(
  [switch]$Release,
  [string]$FeedbackEmail
)

$ErrorActionPreference = 'Stop'

function Write-Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }

if (-not (Test-Path 'pubspec.yaml')) {
  throw 'Run this from the repository root (the folder with pubspec.yaml).'
}
foreach ($cmd in 'flutter', 'adb', 'python') {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "$cmd is not on PATH. Run scripts\windows\setup.ps1, then open a new terminal."
  }
}

Write-Step 'Packages'
flutter pub get

Write-Step 'Bundled light model'
# Downloaded once into assets\models and checked against its SHA-256; git ignores it.
if (Test-Path 'assets\models\light-model.onnx') {
  Write-Host '  already present'
} else {
  python tools\ci\fetch_models.py --tier light --cache .model-cache
}

Write-Step 'Connected devices'
adb devices
$devices = (adb devices | Select-String -Pattern '\tdevice$')
if (-not $devices) {
  Write-Host @'
  No phone found. On the phone:
    1. Settings > About phone > tap "Build number" seven times.
    2. Settings > System > Developer options > turn on "USB debugging".
    3. Connect the USB cable and accept the "Allow USB debugging?" prompt.
  Then run this script again.
'@ -ForegroundColor Yellow
  exit 1
}

$defines = @()
if ($FeedbackEmail) { $defines += "--dart-define=FEEDBACK_EMAIL=$FeedbackEmail" }

if ($Release) {
  if (-not (Test-Path 'android\key.properties')) {
    throw 'Release builds need android\key.properties (see docs\build-on-windows.md).'
  }
  Write-Step 'Building a signed release APK'
  flutter build apk --release --split-per-abi @defines
  $apk = 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk'
  Write-Step "Installing $apk"
  adb install -r $apk
  Write-Host "`nInstalled. Open the app from the phone's launcher." -ForegroundColor Green
} else {
  Write-Step 'Building and running the debug build (press q to stop)'
  flutter run @defines
}
