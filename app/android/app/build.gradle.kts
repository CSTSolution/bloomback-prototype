import java.io.File
import java.util.Properties

// The Google Play upload key lives in OVH/bloomback-android/keystore.env on the building Mac (BB_STORE,
// BB_STORE_PASS, BB_ALIAS, BB_KEY_PASS), never in this repo. Without it, release builds use the debug key.
val playUpload: Properties? = File(System.getProperty("user.home"), "Documents/CST/OVH/bloomback-android/keystore.env")
    .takeIf { it.exists() }
    ?.let { f -> Properties().apply { f.inputStream().use { load(it) } } }

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.cstsolution.bloomback"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs core library desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.cst.bloomback"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_blue_plus needs 21+; BLUETOOTH_SCAN/CONNECT rules start at 31 (API 12).
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        playUpload?.let { keys ->
            create("playUpload") {
                storeFile = file(keys.getProperty("BB_STORE"))
                storePassword = keys.getProperty("BB_STORE_PASS")
                keyAlias = keys.getProperty("BB_ALIAS")
                keyPassword = keys.getProperty("BB_KEY_PASS")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("playUpload") ?: signingConfigs.getByName("debug")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
