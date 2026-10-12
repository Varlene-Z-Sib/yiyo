import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()

val keystorePropertiesFile =
    rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(
        FileInputStream(
            keystorePropertiesFile
        )
    )
}

android {
    namespace = "com.coded.yiyo"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility =
            JavaVersion.VERSION_11

        targetCompatibility =
            JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget =
            JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        val mapsApiKey =
            project.findProperty(
                "GOOGLE_MAPS_API_KEY"
            ) as String? ?: ""

        applicationId = "com.coded.yiyo"

        minSdk = 23
        targetSdk = 36

        versionCode =
            flutter.versionCode

        versionName =
            flutter.versionName

        manifestPlaceholders[
            "GOOGLE_MAPS_API_KEY"
        ] = mapsApiKey
    }

    signingConfigs {
        create("release") {
            keyAlias =
                keystoreProperties.getProperty(
                    "keyAlias"
                )

            keyPassword =
                keystoreProperties.getProperty(
                    "keyPassword"
                )

            storeFile =
                keystoreProperties
                    .getProperty(
                        "storeFile"
                    )
                    ?.let {
                        file(it)
                    }

            storePassword =
                keystoreProperties.getProperty(
                    "storePassword"
                )
        }
    }

    buildTypes {
        release {
            signingConfig =
                signingConfigs.getByName(
                    "release"
                )
        }
    }
}

flutter {
    source = "../.."
}