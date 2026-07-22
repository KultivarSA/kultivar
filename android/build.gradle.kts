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
// Both compilers are configured with lazy `configureEach` (NOT
// afterEvaluate): the pre-existing `evaluationDependsOn(":app")` above
// means some subprojects are already evaluated by the time this block
// runs, and calling afterEvaluate on an evaluated project throws
// "Cannot run Project.afterEvaluate when the project is already
// evaluated".  configureEach applies at task-realization time, which is
// safe regardless of evaluation state and runs after AGP's own setup,
// so our target wins.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
        .configureEach {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
