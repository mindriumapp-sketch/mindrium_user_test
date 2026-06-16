import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase는 사용하지 않으므로 Google Services 플러그인 제거
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val requiredKeystoreProperties = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

fun keystoreProperty(name: String): String {
    return keystoreProperties.getProperty(name)?.trim().orEmpty()
}

val missingKeystoreProperties = requiredKeystoreProperties.filter { keystoreProperty(it).isEmpty() }
val releaseStoreFilePath = keystoreProperty("storeFile")
val releaseStoreFileExists = releaseStoreFilePath.isNotEmpty() && file(releaseStoreFilePath).exists()
val hasCompleteReleaseKeystore =
    keystorePropertiesFile.exists() && missingKeystoreProperties.isEmpty() && releaseStoreFileExists
val releaseKeystoreError = when {
    !keystorePropertiesFile.exists() ->
        "Missing android/key.properties. Release builds require storeFile, storePassword, keyAlias, and keyPassword."
    missingKeystoreProperties.isNotEmpty() ->
        "Missing ${missingKeystoreProperties.joinToString()} in android/key.properties."
    !releaseStoreFileExists ->
        "Release keystore file not found: $releaseStoreFilePath"
    else -> ""
}

gradle.taskGraph.whenReady {
    val runsReleaseTask = allTasks.any { task ->
        task.path.startsWith(":app:") && task.name.contains("Release")
    }

    if (runsReleaseTask && !hasCompleteReleaseKeystore) {
        throw GradleException(releaseKeystoreError)
    }
}

android {
    namespace = "com.mindrium.gad_app_team"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mindrium.gad_app_team"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasCompleteReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperty("keyAlias")
                keyPassword = keystoreProperty("keyPassword")
                storeFile = file(releaseStoreFilePath)
                storePassword = keystoreProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasCompleteReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // Firebase는 사용하지 않으므로 의존성 제거
}
