group = "town.leggy.animated_stickers"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.4.21"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.5.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "town.leggy.animated_stickers"

    compileSdk = 36

    // The prebuilt libyuv references NDK r30's compiler-rt (SME helpers), so
    // the native build needs r30 or newer (ADR 0009).
    ndkVersion = "30.0.16248370"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24

        // Keeps the JNI entry points and callbacks through app R8 passes.
        consumerProguardFiles("proguard-rules.pro")

        // The prebuilts cover these ABIs (x86 is opt-in; see build-android.sh).
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    // The C++ core plus the JNI texture glue as libanimated_stickers.so, loaded by
    // dart:ffi and System.loadLibrary.
    externalNativeBuild {
        cmake {
            path = file("CMakeLists.txt")
            version = "3.22.1"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
