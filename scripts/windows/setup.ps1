<#
.SYNOPSIS
  One-off setup for building UK Pronunciation Coach on Windows and running it on a
  connected Android phone.

.DESCRIPTION
  Installs Git, Temurin JDK 17, the Flutter SDK and the Android command-line tools with
  winget, accepts the Android SDK licences, and installs the platform and build-tools the
  app needs (compileSdk 37, minSdk 29). Safe to re-run: anything already present is left
  alone. Nothing is installed system-wide that winget cannot uninstall.

.PARAMETER FlutterRoot
  Where to put the Flutter SDK. Default C:\src\flutter (keep the path short and
  space-free: Gradle and the NDK dislike long paths).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\windows\setup.ps1
#>
[CmdletBinding()]
param(
  [string]$FlutterRoot = 'C:\src\flutter',
  [string]$FlutterVersion = '3.47.7'
)

$ErrorActionPreference = 'Stop'

function Write-Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Have($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

function Install-IfMissing($command, $wingetId, $label) {
  if (Have $command) {
    Write-Host "  $label already installed"
    return
  }
  Write-Step "Installing $label"
  winget install --id $wingetId --exact --silent `
    --accept-package-agreements --accept-source-agreements
}

function Add-ToUserPath($dir) {
  $current = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($current -split ';' -contains $dir) { return }
  [Environment]::SetEnvironmentVariable('Path', "$current;$dir", 'User')
  $env:Path = "$env:Path;$dir"
  Write-Host "  added to your PATH: $dir"
}

if (-not (Have winget)) {
  throw 'winget is required. Install "App Installer" from the Microsoft Store, then re-run.'
}

Install-IfMissing 'git'    'Git.Git'                     'Git'
Install-IfMissing 'java'   'EclipseAdoptium.Temurin.17.JDK' 'Temurin JDK 17'
Install-IfMissing 'python' 'Python.Python.3.12'          'Python 3.12'

# Flutter: winget's package tracks the latest stable, so clone the pinned version instead
# (the same one CI uses, so local builds match).
Write-Step "Flutter SDK $FlutterVersion"
if (Test-Path (Join-Path $FlutterRoot 'bin\flutter.bat')) {
  Write-Host "  already at $FlutterRoot"
} else {
  $parent = Split-Path $FlutterRoot -Parent
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  git clone --depth 1 --branch $FlutterVersion https://github.com/flutter/flutter.git $FlutterRoot
}
Add-ToUserPath (Join-Path $FlutterRoot 'bin')

Write-Step 'Android command-line tools'
if (Have sdkmanager) {
  Write-Host '  already installed'
} else {
  winget install --id Google.AndroidStudio --exact --silent `
    --accept-package-agreements --accept-source-agreements
  Write-Host '  Android Studio installed. Open it once and let it finish its first-run'
  Write-Host '  setup (it installs the SDK and platform-tools), then re-run this script.'
}

$sdk = $env:ANDROID_SDK_ROOT
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
if (Test-Path $sdk) {
  [Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $sdk, 'User')
  $env:ANDROID_SDK_ROOT = $sdk
  Add-ToUserPath (Join-Path $sdk 'platform-tools')

  $sdkmanager = Get-ChildItem -Path $sdk -Filter 'sdkmanager.bat' -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($sdkmanager) {
    Write-Step 'Android SDK packages (platform 37, build-tools, platform-tools)'
    # The app compiles against SDK 37; minSdk is 29.
    & $sdkmanager.FullName 'platform-tools' 'platforms;android-37' 'build-tools;37.0.0' | Out-Null
    Write-Step 'Accepting Android SDK licences'
    & $sdkmanager.FullName --licenses | Out-Null
  }
} else {
  Write-Host "  Android SDK not found at $sdk - open Android Studio once, then re-run."
}

Write-Step 'flutter doctor'
& (Join-Path $FlutterRoot 'bin\flutter.bat') doctor

Write-Host "`nSetup finished. Open a NEW terminal so the PATH changes apply, then:" -ForegroundColor Green
Write-Host '  scripts\windows\run-on-phone.ps1'
