import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (R1-release, docs/release.md). Values come from, in order:
//   1. android/key.properties (git-ignored; local release builds), keys storeFile,
//      storePassword, keyAlias, keyPassword; storeFile is relative to android/app/;
//   2. environment variables (CI, from GitHub secrets): ANDROID_KEYSTORE_PATH,
//      ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD.
// Without either, release builds fall back to the debug key so `flutter run --release`
// works on a developer machine; such builds cannot go to Play. CI sets
// REQUIRE_RELEASE_SIGNING=true so a missing secret fails the build instead.
val keyProperties =
    Properties().apply {
        val file = rootProject.file("key.properties")
        if (file.exists()) file.inputStream().use { load(it) }
    }

fun signingValue(
    property: String,
    env: String,
): String? = keyProperties.getProperty(property) ?: System.getenv(env)?.takeIf { it.isNotBlank() }

val releaseStoreFile = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val hasReleaseSigning =
    releaseStoreFile != null &&
        signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD") != null &&
        signingValue("keyAlias", "ANDROID_KEY_ALIAS") != null &&
        signingValue("keyPassword", "ANDROID_KEY_PASSWORD") != null

if (!hasReleaseSigning && System.getenv("REQUIRE_RELEASE_SIGNING") == "true") {
    throw GradleException(
        "Release signing is required but not configured: set ANDROID_KEYSTORE_PATH, " +
            "ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS and ANDROID_KEY_PASSWORD " +
            "(see docs/release.md).",
    )
}

android {
    namespace = "uk.pronunciationcoach.uk_pronunciation_coach"
    // 37 instead of Flutter's default (36): permission_handler_android 14.x requires it.
    // targetSdk stays on Flutter's default.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (daily practice reminder).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Permanent once the app is on Google Play (docs/release.md, "Identifiers").
        applicationId = "uk.pronunciationcoach.uk_pronunciation_coach"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29 // Android 10 (spec minimum)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseSigning) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
            // R8: shrink and optimise Java/Kotlin code and drop unused resources. The
            // plug-ins ship their own consumer rules; proguard-rules.pro adds what
            // ONNX Runtime and Flutter need, and res/raw/keep.xml keeps the
            // notification icon that is looked up by name.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Java 8+ APIs on older Android for flutter_local_notifications. Licence:
    // GPL-2.0 with the Classpath Exception (owner-approved exception, docs/licences.md).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
