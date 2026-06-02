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

    // Kotlin version: the sweet spot between two opposing constraints.
    //
    // CONSTRAINT A -- floor:
    //   Modern Flutter SDK (>= 3.27) bundles kotlin-stdlib 2.2.20 onto
    //   the classpath of every Android build.  A project Kotlin compiler
    //   older than 2.1 cannot read the binary metadata of a 2.2 stdlib:
    //
    //     e: kotlin-stdlib-2.2.20.jar Module was compiled with an
    //     incompatible version of Kotlin.  The binary version of its
    //     metadata is 2.2.0, expected version is 2.0.0.
    //
    //   So we need >= 2.1.0.  Flutter's own warning is also clear:
    //   'Flutter support for your project's Kotlin version (2.0.x) will
    //   soon be dropped.  Please upgrade ... at least 2.1.0.'
    //
    // CONSTRAINT B -- ceiling:
    //   Kotlin 2.2 dropped support for language-version 1.6, which
    //   sentry_flutter 8.x and several other indirect Android plugins
    //   still declare in their compileDebugKotlin task config:
    //
    //     e: Language version 1.6 is no longer supported;
    //     please, use version 1.8 or greater.
    //
    //   So we need < 2.2.0.
    //
    // 2.1.20 satisfies both: meets Flutter's minimum, still accepts
    // language-version 1.6 (deprecated but tolerated through the 2.1.x
    // line), reads 2.2 stdlib metadata via forward-compat ABI guarantees.
    //
    // Re-bump to 2.2.x when sentry_flutter moves to 9.x AND every other
    // Android plugin in the dep tree declares language-version >= 1.8.
    // Track via `cd android && ./gradlew :sentry_flutter:dependencies`.
    id("org.jetbrains.kotlin.android") version "2.1.20" apply false
}

include(":app")
