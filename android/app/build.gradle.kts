plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val meetTraceReleaseStoreFile =
    providers.environmentVariable("MEETTRACE_ANDROID_KEYSTORE_PATH").orNull
val meetTraceReleaseStorePassword =
    providers.environmentVariable("MEETTRACE_ANDROID_KEYSTORE_PASSWORD").orNull
val meetTraceReleaseKeyAlias =
    providers.environmentVariable("MEETTRACE_ANDROID_KEY_ALIAS").orNull
val meetTraceReleaseKeyPassword =
    providers.environmentVariable("MEETTRACE_ANDROID_KEY_PASSWORD").orNull
val meetTraceReleaseSigningConfigured =
    listOf(
        meetTraceReleaseStoreFile,
        meetTraceReleaseStorePassword,
        meetTraceReleaseKeyAlias,
        meetTraceReleaseKeyPassword,
    ).all { !it.isNullOrBlank() }

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
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    testOptions {
        // OnePlus Android 16 cannot bind androidx.test.services; direct
        // instrumentation keeps Patrol reliable on the current target device.
        execution = "HOST"
    }

    signingConfigs {
        if (meetTraceReleaseSigningConfigured) {
            create("release") {
                storeFile = file(requireNotNull(meetTraceReleaseStoreFile))
                storePassword = meetTraceReleaseStorePassword
                keyAlias = meetTraceReleaseKeyAlias
                keyPassword = meetTraceReleaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
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
