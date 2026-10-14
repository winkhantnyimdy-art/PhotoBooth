import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials live in android/key.properties, which is
// untracked (see android/.gitignore) and must never be committed. A release
// build without them fails here, at configuration time, with instructions -
// there is deliberately no debug-key fallback for release builds, so a
// misconfigured machine can never ship a debug-signed APK from the website.
// Debug builds never touch this file and keep working without a keystore.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

val isReleaseBuild =
    gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }

fun requireKeystoreProperty(key: String): String {
    val value = (keystoreProperties[key] as String?)?.trim().orEmpty()
    if (value.isEmpty()) {
        throw GradleException(
            "Release signing is misconfigured: android/key.properties does not " +
                "define \"$key\". See docs/ANDROID_RELEASE.md section 3 for the " +
                "required keys (storeFile, storePassword, keyAlias, keyPassword)."
        )
    }
    return value
}

if (isReleaseBuild) {
    if (!keystorePropertiesFile.exists()) {
        throw GradleException(
            "Cannot sign the release build: android/key.properties was not found. " +
                "Create the release keystore once on a secure machine, save its " +
                "passwords in android/key.properties (untracked - never commit it), " +
                "then rerun the release build. " +
                "See docs/ANDROID_RELEASE.md section 3. " +
                "Do not generate signing keys without explicit approval."
        )
    }
    val storeFileValue = requireKeystoreProperty("storeFile")
    if (!rootProject.file(storeFileValue).exists()) {
        throw GradleException(
            "Cannot sign the release build: the keystore " +
                "\"$storeFileValue\" listed in android/key.properties does not exist. " +
                "Check the storeFile path (relative to the android/ directory) and " +
                "restore the keystore from the offline backup."
        )
    }
}

android {
    namespace = "com.photobooth.photo_booth"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Deliberately kept: changing the application ID orphans existing
        // installs (see docs/ANDROID_RELEASE.md). Do not change without
        // approval and a migration plan.
        applicationId = "com.photobooth.photo_booth"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                // storeFile is resolved relative to the android/ directory.
                storeFile = rootProject.file(requireKeystoreProperty("storeFile"))
                storePassword = requireKeystoreProperty("storePassword")
                keyAlias = requireKeystoreProperty("keyAlias")
                keyPassword = requireKeystoreProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Uses the release keystore from android/key.properties. When the
            // file is absent (day-to-day development), no release config
            // exists and non-release builds are unaffected; any release
            // build fails early with instructions instead of silently
            // falling back to debug keys.
            signingConfig = signingConfigs.findByName("release")
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
