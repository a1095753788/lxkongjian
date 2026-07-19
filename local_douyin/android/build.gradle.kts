allprojects {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
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
    beforeEvaluate {
        if (file("src/main/kotlin").exists()) {
            project.apply(plugin = "org.jetbrains.kotlin.android")
        }
    }

    afterEvaluate {
        extensions.findByName("android")?.let { androidExt ->
            val isLibrary = pluginManager.hasPlugin("com.android.library")
            val isApplication = pluginManager.hasPlugin("com.android.application")

            if (isLibrary || isApplication) {
                when {
                    isApplication -> {
                        (androidExt as com.android.build.api.dsl.ApplicationExtension).compileSdk = 36
                    }
                    isLibrary -> {
                        (androidExt as com.android.build.api.dsl.LibraryExtension).compileSdk = 36
                    }
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
