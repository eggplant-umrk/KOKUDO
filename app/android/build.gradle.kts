allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// maplibre_gl 0.27.0 の android/build.gradle は、AGP 9 が Kotlin を内蔵している前提で
// android.kotlinOptions ではなく `kotlin { compilerOptions { ... } }` を使っている。
// 一方 cloud_firestore などのプラグインは従来どおり自前で kotlin-android を適用するため、
// android.builtInKotlin=true にすると「AGP 9 以降 kotlin-android は不要」として弾かれる。
// どちらのフラグでも片方が壊れるので、builtInKotlin は false のままにしたうえで、
// Android ライブラリとして構成されるサブプロジェクトにこちらから KGP を適用し、
// kotlin 拡張が必ず存在する状態を作る。既に適用済みのプロジェクトでは no-op になる。
subprojects {
    plugins.withId("com.android.library") {
        apply(plugin = "org.jetbrains.kotlin.android")
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
