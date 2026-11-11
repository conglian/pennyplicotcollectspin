plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // 仅当google-services.json包含当前应用包名时应用，避免误用旧示例Firebase应用。
    id("com.google.gms.google-services") apply false
}

val pennyApplicationId = "com.moolash.jarpiggy.pro"
val pennyGoogleServices = file("google-services.json")
if (pennyGoogleServices.exists() &&
    Regex("\\\"package_name\\\"\\s*:\\s*\\\"${Regex.escape(pennyApplicationId)}\\\"")
        .containsMatchIn(pennyGoogleServices.readText())) {
    apply(plugin = "com.google.gms.google-services")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    // Flutter在构建前直接解析源码，需要字面量；与pennyApplicationId保持一致。
    namespace = "com.moolash.jarpiggy.pro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // 启用核心库脱糖
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.moolash.jarpiggy.pro"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        minSdkVersion(27)
        targetSdkVersion(36)
    }

    signingConfigs {
        create("release") {
            storeFile = file("/Users/aurastack/Desktop/pennyplicotcollectspinsings.jks")
            storePassword = "123456"
            keyAlias = "pennyplicotcollectspinsings"
            keyPassword = "123456"
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
//                "proguard-chartboost-mediation.pro"
            )
            // 5.3.0 自带 -printmapping，会向 Gradle 不可变缓存写入映射；保留其余原规则。
//            optimization {
//                keepRules {
//                    ignoreFrom("com.chartboost:chartboost-mediation-sdk:5.3.0")
//                }
//            }
        }
    }
}


flutter {
    source = "../.."
}

dependencies {
    // facebook
    implementation ("com.facebook.android:facebook-android-sdk:latest.release")
    // When using the BoM, you don't specify versions in Firebase library dependencies
    implementation("com.google.firebase:firebase-crashlytics-ndk")
    implementation("com.google.firebase:firebase-analytics")
    implementation(platform("com.google.firebase:firebase-bom:34.4.0"))

    // 添加核心库脱糖依赖 通知需要
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // Adjust v5 is provided by adjust_sdk; do not pin the retired Android v4 SDK.

    // CloudX core matches cloudx_flutter 3.11.0. Adapters use an open core range.
    implementation("io.cloudx:sdk") { version { strictly("4.10.0") } }
    // Share the exact network SDK versions with TopOn to avoid adapter conflicts.
    implementation("io.cloudx:adapter-digitalturbine:8.4.2.0")
    implementation("io.cloudx:adapter-googlewaterfall:25.2.0.6") // AdMob + GAM estimated
    implementation("io.cloudx:adapter-inmobi:11.1.1.0")
    implementation("io.cloudx:adapter-meta:6.21.0.3")
    implementation("io.cloudx:adapter-mintegral:17.0.91.0")
    implementation("io.cloudx:adapter-moloco:4.10.1.0")
    implementation("io.cloudx:adapter-pangle:8.1.0.3.0")
    implementation("io.cloudx:adapter-unityads:4.17.0.0")
    implementation("io.cloudx:adapter-vungle:7.7.3.0")

    // TU (Necessary)
    api("com.thinkup.sdk:core-tpn:6.5.73.3")

    // AndroidX (Necessary)
    api("androidx.appcompat:appcompat:1.6.1")
    api("androidx.browser:browser:1.4.0")

    // Moloco
    api("com.thinkup.sdk:adapter-tpn-moloco:4.10.1.1.0")
    api("com.moloco.sdk:moloco-sdk:4.10.1")

    // Vungle
    api("com.thinkup.sdk:adapter-tpn-vungle:7.7.3.1.0")
    api("com.vungle:vungle-ads:7.7.3")
    api("com.google.android.gms:play-services-basement:18.1.0")
    api("com.google.android.gms:play-services-ads-identifier:18.0.1")

    // UnityAds
    api("com.thinkup.sdk:adapter-tpn-unityads:4.17.0.1.1")
    api("com.unity3d.ads:unity-ads:4.17.0")

    // Ironsource
    api("com.thinkup.sdk:adapter-tpn-ironsource:9.2.0.1.1")
    api("com.unity3d.ads-mediation:mediation-sdk:9.2.0")
    api("com.google.android.gms:play-services-appset:16.0.2")
    api("com.google.android.gms:play-services-ads-identifier:18.0.1")
    api("com.google.android.gms:play-services-basement:18.1.0")

    // Bigo
    api("com.thinkup.sdk:adapter-tpn-bigo:5.7.1.1.1")
    api("com.bigossp:bigo-ads:5.7.1")

    // Pangle
    api("com.thinkup.sdk:adapter-tpn-pangle:8.1.0.3.1.0")
    api("com.pangle.global:pag-sdk:8.1.0.3")
    api("com.google.android.gms:play-services-ads-identifier:18.2.0")

    // Kwai
    api("com.thinkup.sdk:adapter-tpn-kwai:1.2.21.1.0")
    api("io.github.kwainetwork:adApi:1.2.21")
    api("io.github.kwainetwork:adImpl:1.2.21")
    api("androidx.media3:media3-exoplayer:1.0.0-alpha01")
    api("androidx.appcompat:appcompat:1.6.1")
    api("com.google.android.material:material:1.2.1")
    api("androidx.annotation:annotation:1.2.0")
    api("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.4.10")
    api("com.google.android.gms:play-services-ads-identifier:18.0.1")

    // Facebook
    api("com.thinkup.sdk:adapter-tpn-facebook:6.21.0.1.1")
    api("com.facebook.android:audience-network-sdk:6.21.0")
    api("androidx.annotation:annotation:1.0.0")

    // Admob
    api("com.thinkup.sdk:adapter-tpn-admob:25.2.0.1.0")
    api("com.google.android.gms:play-services-ads:25.2.0")

    // Inmobi
    api("com.thinkup.sdk:adapter-tpn-inmobi:11.1.1.1.1")
    api("com.inmobi.monetization:inmobi-ads-kotlin:11.1.1")

    // TU Adx SDK (Necessary)
    api("com.thinkup.sdk:adapter-tpn-sdm:6.5.68.1.0")
    api("com.smartdigimkttech.sdk:smartdigimkttech-sdk:6.5.68")

    // AppLovin
    api("com.thinkup.sdk:adapter-tpn-applovin:13.6.0.1.1")
    api("com.applovin:applovin-sdk:13.6.0")

    // Mintegral
    api("com.thinkup.sdk:adapter-tpn-mintegral:17.0.91.1.0")
    api("com.mbridge.msdk.oversea:mbridge_android_sdk:17.0.91")
    api("androidx.recyclerview:recyclerview:1.1.0")

    // Bidmachine
    api("com.thinkup.sdk:adapter-tpn-bidmachine:3.7.0.1.0")
    api("io.bidmachine:ads:3.7.0")

    // Chartboost
    api("com.thinkup.sdk:adapter-tpn-chartboost:9.12.0.1.0")
    api("com.chartboost:chartboost-sdk:9.12.0")
    api("com.chartboost:chartboost-mediation-sdk:5.3.0")
    api("com.chartboost:chartboost-core-sdk:1.1.0")
    api("com.chartboost:chartboost-mediation-adapter-chartboost:5.9.11.0.0")
    api("androidx.media3:media3-exoplayer:1.4.1")
    api("androidx.media3:media3-ui:1.4.1")
    api("com.jakewharton.retrofit:retrofit2-kotlinx-serialization-converter:1.0.0")
    api("com.squareup.okhttp3:logging-interceptor:4.11.0")
    api("com.squareup.okhttp3:okhttp:4.12.0")
    api("com.squareup.retrofit2:converter-scalars:2.9.0")
    api("com.squareup.retrofit2:retrofit:2.9.0")
    api("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    api("org.jetbrains.kotlinx:kotlinx-serialization-json:1.5.1")

    // Fyber
    api("com.thinkup.sdk:adapter-tpn-fyber:8.4.2.1.1")
    api("com.fyber:marketplace-sdk:8.4.2")
    api("com.google.android.gms:play-services-basement:18.9.0")
    api("com.google.android.gms:play-services-ads-identifier:18.0.1")

    // Tramini
    api("com.thinkup.sdk:tramini-plugin-tpn:6.5.73")


}
