import java.util.Properties

plugins {
  kotlin("android") version "2.1.0" apply false
  id("com.android.application") version "8.7.0" apply false
  // Firebase는 사용하지 않으므로 Google Services 플러그인 제거
}

buildscript {
    repositories {
        google()
        mavenCentral()
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootDir.resolve("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use(::load)
    }
}

val flutterSdkPath = localProperties.getProperty("flutter.sdk")
val flutterDartExecutable = flutterSdkPath?.let { "$it/bin/dart" }

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")

    if (project.name == "rive_native" && flutterDartExecutable != null) {
        afterEvaluate {
            val androidExtension = extensions.findByName("android") ?: return@afterEvaluate
            val defaultConfig = androidExtension.javaClass.methods
                .firstOrNull { it.name == "getDefaultConfig" }
                ?.invoke(androidExtension)
                ?: return@afterEvaluate
            val externalNativeBuild = defaultConfig.javaClass.methods
                .firstOrNull { it.name == "getExternalNativeBuild" }
                ?.invoke(defaultConfig)
                ?: return@afterEvaluate
            val cmake = externalNativeBuild.javaClass.methods
                .firstOrNull { it.name == "getCmake" }
                ?.invoke(externalNativeBuild)
                ?: return@afterEvaluate
            val arguments = cmake.javaClass.methods
                .firstOrNull { it.name == "getArguments" }
                ?.invoke(cmake) as? MutableCollection<Any>
                ?: return@afterEvaluate

            val dartArgument = "-DDART_EXECUTABLE=$flutterDartExecutable"
            if (!arguments.contains(dartArgument)) {
                arguments.add(dartArgument)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
