group = "com.platojobs.nrf_mesh"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.2.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
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
    id("kotlin-android")
}

android {
    namespace = "com.platojobs.nrf_mesh"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
        freeCompilerArgs += listOf(
            // Nordic Kotlin BLE client artifacts may contain pre-release Kotlin metadata.
            // We build with a stable Kotlin compiler; skip the check to allow compilation.
            "-Xskip-prerelease-check",
        )
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

dependencies {
    // Nordic Kotlin BLE client (required by bearer-gatt)
    implementation("no.nordicsemi.kotlin.ble:client-android:2.0.0-alpha19")
    // Nordic Kotlin Mesh Library (replaces legacy no.nordicsemi.android:mesh)
    implementation("no.nordicsemi.kotlin.mesh:bearer:1.0.0")
    implementation("no.nordicsemi.kotlin.mesh:bearer-gatt:1.0.0")
    implementation("no.nordicsemi.kotlin.mesh:bearer-pbgatt:1.0.0")
    implementation("no.nordicsemi.kotlin.mesh:bearer-provisioning:1.0.0")
    implementation("no.nordicsemi.kotlin.mesh:core:1.0.0")
    implementation("no.nordicsemi.kotlin.mesh:provisioning:1.0.0")
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.14.2")
}
