import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// リリース署名の情報は android/key.properties から読む。
// このファイルは .gitignore 済みで、リポジトリには入らない(鍵本体も同様)。
// 中身は次の4行:
//   storePassword=...
//   keyPassword=...
//   keyAlias=...
//   storeFile=C:/path/to/kokudo-release.jks
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

android {
    namespace = "com.eggplantumrk.kokudo.kokudo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Google Play 上でこのアプリを一意に指すID。公開後は変更できず、
        // ストアのURL(play.google.com/store/apps/details?id=...)にも出る。
        //
        // 以前は Flutter がプロジェクト作成時に自動で付けた
        // com.eggplantumrk.kokudo.kokudo だった(GitHubの組織名由来で、
        // kokudo が2回入っていた)。Play Console 側のアプリ枠はこちらの名前で
        // 登録されているので、そちらに合わせる。
        //
        // 上の namespace はビルド時にだけ使う内部的な名前空間で、これとは
        // 別物。変えると Kotlin のパッケージ宣言まで動かすことになるので
        // 据え置く。2つが違っていても問題はない。
        applicationId = "com.zerotomedapp.KOKUDO"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storePassword = keystoreProperties.getProperty("storePassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
        }
    }

    buildTypes {
        release {
            // key.properties が無い環境(鍵を持っていない開発者やCI)では、
            // これまで通りデバッグ鍵で署名して `flutter run --release` を通す。
            // その成果物はストアには出せない。
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
