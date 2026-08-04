plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.meettrace.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.meettrace.app"
        val flutterTarget =
            providers.gradleProperty("target").orNull?.replace('\\', '/')
        val isLivePreviewReplayTarget =
            flutterTarget?.endsWith(
                "integration_test/live_preview_replay_test.dart"
            ) == true
        if (
            isLivePreviewReplayTarget ||
            providers.environmentVariable("MEETTRACE_REPLAY_TEST_PACKAGE").orNull ==
                "true"
        ) {
            applicationIdSuffix = ".replaytest"
            versionNameSuffix = "-replaytest"
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
