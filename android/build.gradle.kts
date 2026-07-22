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

// Force jvmTarget 17 on every module's Kotlin compilation.
//
// home_widget 0.9.1 (and some other plugins) default their Kotlin
// compilation to jvmTarget 1.8 while inlining bytecode from AndroidX
// dependencies built for JVM 11.  Kotlin 2.x then fails the build with:
//   Cannot inline bytecode built with JVM target 11 into bytecode that
//   is being built with JVM target 1.8.
// Pinning every subproject to 17 (matching :app, which already targets
// Java/Kotlin 17) keeps the toolchain consistent.  Surfaced when the
// purchases_flutter 8 -> 10 upgrade (Play Billing Library 8) shifted
// the Kotlin toolchain resolution.
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
