import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials, read from `android/key.properties`.
//
// That file and the keystore it points at are gitignored and never leave
// the machine: a leaked upload key means somebody else can publish an
// update to this app. See `docs/ANDROID_RELEASE_SIGNING.md`.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore =
    keystorePropertiesFile.exists().also { exists ->
        if (exists) FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
    } &&
        listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            .all { !(keystoreProperties.getProperty(it)?.isBlank() ?: true) }

android {
    namespace = "com.gospeltube_app.gospeltube_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.gospeltube_app.gospeltube_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Declared only when the credentials are actually present, so a
        // fresh clone configures without a keystore instead of failing on a
        // null cast.
        if (hasKeystore) {
            create("release") {
                val path = keystoreProperties.getProperty("storeFile")
                // A relative path is read from `android/`, beside
                // key.properties itself; an absolute one is taken as given.
                storeFile = File(path).takeIf(File::isAbsolute) ?: rootProject.file(path)
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasKeystore) {
                    signingConfigs.getByName("release")
                } else {
                    // Keeps `flutter run --release` working on a machine
                    // with no upload key. Play rejects a debug-signed
                    // upload, so this cannot reach production unnoticed.
                    logger.warn(
                        "WARNING: android/key.properties is missing or incomplete — " +
                            "release builds are being signed with the DEBUG key and " +
                            "cannot be uploaded to Play. See docs/ANDROID_RELEASE_SIGNING.md",
                    )
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}
