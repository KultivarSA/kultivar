plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.Kultivar"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.Kultivar"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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

flutter {
    source = "../.."
}

dependencies {
    // Companion to isCoreLibraryDesugaringEnabled = true above.
    // Provides backported Java 8+ APIs (java.time, java.util.stream,
    // etc.) so plugins that ship modern Java code can target older
    // Android runtimes via Android's R8 desugar process.
    //
    // 2.0.4 is the current stable release; bump in lockstep with
    // AGP major bumps.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
