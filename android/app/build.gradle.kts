plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.safe_travel_app"
    
    // Use an explicit compileSdk to ensure plugin compatibility (geolocator recommends 35)
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Enable core library desugaring required by some plugin AARs (e.g. flutter_local_notifications)
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.safe_travel_app"
    // You can update the following values to match your application needs.
    // For more information, see: https://flutter.dev/to/review-gradle-config.
    // another_telephony requires minSdk 23; set explicitly to satisfy plugin
    minSdk = 23
    // Use explicit targetSdk to ensure the Android plugins compile against a compatible SDK
    targetSdk = 35
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

// Add desugaring dependency required when core library desugaring is enabled.
dependencies {
    // Use a recent desugar_jdk_libs release compatible with Android Gradle Plugin.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
// Conditionally apply Google Services plugin if google-services.json is present
val googleServicesJson = file("${project.projectDir}/google-services.json")
if (googleServicesJson.exists()) {
    logger.lifecycle("Applying Google Services plugin (google-services.json found)")
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle("Skipping Google Services plugin (google-services.json not found)")
}
