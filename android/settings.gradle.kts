pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false

    // Kotlin 2.2 dropped support for language-version 1.6, which
    // sentry_flutter 8.14 (and several other indirect Android plugins)
    // still declare in their `compileDebugKotlin` task config.  Compiling
    // those plugins against Kotlin 2.2 fails with:
    //
    //   e: Language version 1.6 is no longer supported;
    //   please, use version 1.8 or greater.
    //
    // Kotlin 2.0.21 still accepts language-version 1.6 while giving us
    // a modern compiler + K2 features.  Re-bump to 2.1.x or 2.2.x once
    // every Android dependency declares language-version 1.8+ in their
    // build.gradle -- track via `gradlew :sentry_flutter:dependencies`.
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}

include(":app")
