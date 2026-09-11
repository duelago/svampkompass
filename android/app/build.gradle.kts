import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import java.util.Properties

// Signeringsuppgifter läses ur android/key.properties, som aldrig checkas in.
// Saknas filen faller bygget tillbaka på debug-signering, så att repot går att
// bygga för den som klonar det utan tillgång till nyckeln.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "bengtsson.net.svampkompass"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "bengtsson.net.svampkompass"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Android Gradle Plugin lägger annars in ett signerat beroendeblock i
    // APK:ns signaturblock. Det är en krypterad protobuf avsedd för Play
    // Store, och F-Droids skanner avvisar den eftersom innehållet inte går
    // att granska: "Found extra signing block 'Dependency metadata'".
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Inte en riktig release-signatur. Ett bygge utan nyckel är
                // avsett för utveckling och kan inte publiceras.
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Versionskoder för det ABI-splittade bygget.
//
// Flutters standard lägger ABI-siffran överst: abiKod * 1000 + bas, vilket ger
// 3003 / 4003 / 6003 för basen 2003. Det går sönder vid nästa version, för då
// är gamla arm64 (4003) högre än nya armeabi (3004). F-Droid behåller bara
// APK:erna med högst versionskod och arkiverar resten, så en armeabi-telefon
// skulle aldrig få uppdateringen.
//
// F-Droid kräver därför att ABI-siffran ligger längst ner: bas * 10 + abiKod,
// alltså 20031 / 20032 / 20033. Då ligger alla koder för en ny version över
// alla koder för den gamla. Ordningen armeabi-v7a < arm64-v8a < x86_64 är
// också deras krav, eftersom klienten väljer högsta installerbara kod.
//
// Se https://f-droid.org/en/docs/Submitting_to_F-Droid_Quick_Start_Guide/#setup-abi-split
// Motsvaras av VercodeOperation '10 * %c + 1/2/3' i fdroiddata-receptet -- de
// två måste ändras tillsammans.
val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abiVersionCode = abiCodes[output.filters.find { it.filterType == "ABI" }?.identifier]
        if (abiVersionCode != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride =
                variant.versionCode * 10 + abiVersionCode
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}