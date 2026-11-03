import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.argomulyo.surat"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            val keyPasswordVal = keystoreProperties.getProperty("keyPassword")
            val keyAliasVal = keystoreProperties.getProperty("keyAlias")
            val storePasswordVal = keystoreProperties.getProperty("storePassword")
            val storeFileVal = keystoreProperties.getProperty("storeFile")

            if (storeFileVal != null) {
                keyAlias = keyAliasVal
                keyPassword = keyPasswordVal
                storePassword = storePasswordVal
                storeFile = if (file(storeFileVal).isAbsolute) {
                    file(storeFileVal)
                } else {
                    file(storeFileVal)
                }
            }
        }
    }

    defaultConfig {
        applicationId = "com.argomulyo.surat"
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.getByName("release")
            signingConfig = if (releaseSigning.storeFile != null && releaseSigning.storeFile!!.exists()) {
                releaseSigning
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
