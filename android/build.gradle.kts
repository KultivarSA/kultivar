allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Pin every module to Java + Kotlin JVM target 17.
//
// Surfaced when the purchases_flutter 8 -> 10 upgrade (Play Billing
// Library 8) shifted the Kotlin toolchain resolution.  Two symptoms,
// same root cause -- plugins that default their JVM target below :app's
// 17:
//   * home_widget 0.9.1 compiled Kotlin at jvmTarget 1.8 while inlining
//     JVM-11 bytecode from AndroidX deps ->
//       "Cannot inline bytecode built with JVM target 11 into ... 1.8"
//   * audioplayers_android had Kotlin at 17 but Java at 1.8 ->
//       "Inconsistent JVM-target compatibility ... (1.8) and ... (17)"
// Forcing BOTH the Java compileOptions and the Kotlin jvmTarget to 17
// on every subproject (matching :app) keeps the toolchain consistent
// across all plugins at once.  Runs in afterEvaluate so each plugin's
// `android` extension is registered before we configure it.
// Lift every module's Kotlin compilation to jvmTarget 17.
//
// The purchases_flutter 8 -> 10 upgrade (Play Billing Library 8) shifted
// the Kotlin toolchain and broke home_widget 0.9.1, whose Kotlin was
// compiled at jvmTarget 1.8 while inlining JVM-11 bytecode from its
// AndroidX deps:
//   Cannot inline bytecode built with JVM target 11 into bytecode that
//   is being built with JVM target 1.8.
// configureEach is lazy and overrides each plugin's own
// `kotlinOptions.jvmTarget "1.8"`.
//
// We deliberately do NOT try to lift the plugins' Java compileOptions to
// match: several plugins (home_widget, audioplayers_android, …) hardcode
// `compileOptions { VERSION_1_8 }` and AGP finalizes those before we can
// override them.  Instead the resulting Kotlin-17 / Java-8 split within a
// plugin AAR is allowed via `kotlin.jvm.target.validation.mode=warning`
// (android/gradle.properties) — the mixed class-file versions are dexed
// to a single DEX by D8 at app assembly, so it's safe.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
        .configureEach {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
