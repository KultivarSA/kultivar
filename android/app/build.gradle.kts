import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load the upload-keystore credentials from android/key.properties (gitignored).
// When the file is missing -- fresh clone, CI runner without secrets -- the
// release build falls back to debug signing.  That keeps `flutter build apk
// --debug` and `flutter run` working without any keystore present, while
// `flutter build appbundle --release` produces a properly signed AAB once a
// developer has dropped `android/key.properties` in alongside the local
// keystore.  See LAUNCH_ANDROID.md → "Android signing setup".
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "io.kultivar.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // Required by flutter_local_notifications (and a growing number
        // of plugins that ship Java-21 APIs targeting older Android
        // runtimes).  Without this, the Android Gradle Plugin rejects
        // the build with:
        //
        //   Dependency ':flutter_local_notifications' requires core
        //   library desugaring to be enabled for :app.
        //
        // The companion 'coreLibraryDesugaring' dependency below
        // provides the actual replacement implementations.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Pin transitive Android dependencies that home_widget 0.9.1 was
    // pulling in at ALPHA versions (glance-appwidget 1.3.0-alpha01 +
    // compose.remote 1.0.0-alpha11).  Both alpha lines require AGP
    // 9.1.0 + compileSdk 37, which would force a full toolchain
    // upgrade.  Forcing the last stable releases keeps our build on
    // the current stable AGP 8.x line.
    //
    // Remove these forces once home_widget itself pins stable
    // versions in a future release (track via
    // `./gradlew :app:dependencies | findstr -i "glance compose.remote"`).
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.glance" &&
                requested.name == "glance-appwidget") {
                useVersion("1.1.1")
                because("home_widget transitively requests 1.3.0-alpha01")
            }
            if (requested.group == "androidx.compose.remote" &&
                requested.name == "remote-creation-android") {
                useVersion("1.0.0-alpha10")
                because("home_widget transitively requests 1.0.0-alpha11")
            }
        }
    }

    defaultConfig {
        // Production package ID -- locked at v1 launch.
        // Reverse-DNS of kultivar.io with .app suffix so future
        // siblings (io.kultivar.api, io.kultivar.web) stay clean.
        // CRITICAL: this ID cannot change after the first Play
        // Console upload without losing the listing identity.
        applicationId = "io.kultivar.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Production upload keystore.  Only fully configured when
        // android/key.properties is present alongside the .jks file
        // it points at.  We register the config unconditionally so
        // Gradle resolves the symbol on every build; the buildType
        // below picks debug signing when the keystore isn't wired in.
        create("release") {
            if (hasKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile =
                    (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Use the production upload keystore when android/key.properties
            // is present; fall back to debug signing for development builds
            // and CI without secrets so `flutter build apk --debug` keeps
            // working everywhere.
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Companion to isCoreLibraryDesugaringEnabled = true above.
    // Provides backported Java 8+ APIs (java.time, java.util.stream,
    // etc.) so plugins that ship modern Java code can target older
    // Android runtimes via Android's R8 desugar process.
    //
    // flutter_local_notifications declares a minimum desugar_jdk_libs
    // floor in its AAR metadata.  When the project pins below that
    // floor, Gradle fails with:
    //
    //   Dependency ':flutter_local_notifications' requires
    //   desugar_jdk_libs version to be 2.1.4 or above for :app,
    //   which is currently 2.0.4
    //
    // 2.1.4 is the explicit floor demanded by the current version
    // of the notifications plugin.  Bump together with future
    // flutter_local_notifications upgrades.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
