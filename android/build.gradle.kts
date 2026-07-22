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
// Pin every plugin module to JVM target 17 (matching :app).  Several
// Flutter plugins (home_widget 0.9.1, audioplayers_android, …) hardcode
// `compileOptions { VERSION_1_8 }` + `kotlinOptions.jvmTarget "1.8"` in
// their own build.gradle.  The purchases_flutter 8 -> 10 upgrade (Play
// Billing Library 8) shifted the Kotlin toolchain so those defaults now
// fail two ways: home_widget can't inline its JVM-11 AndroidX deps into
// 1.8 bytecode, and any module we lift to Kotlin 17 while its Java stays
// 1.8 trips the "Inconsistent JVM-target compatibility" check.
//
//   * Kotlin: `configureEach` is lazy and wins over the plugin's
//     kotlinOptions.
//   * Java: the plugin bakes compileOptions into its `android` extension
//     during ITS OWN evaluation, so we must re-set them in afterEvaluate
//     (after that build.gradle runs).  Guarded on `state.executed`
//     because the `evaluationDependsOn(":app")` chain leaves some
//     projects already evaluated, and afterEvaluate on an evaluated
//     project throws.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
        .configureEach {
            kotlinOptions {
                jvmTarget = "17"
            }
        }

    val bumpJavaTo17 = {
        (extensions.findByName("android") as? com.android.build.gradle.BaseExtension)
            ?.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        Unit
    }
    if (state.executed) bumpJavaTo17() else afterEvaluate { bumpJavaTo17() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
