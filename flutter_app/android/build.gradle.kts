allprojects {
    repositories {
        google()
        mavenCentral()
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
// Some plugin chains (file_picker -> flutter_plugin_android_lifecycle) declare
// a minCompileSdk higher than the plugin's own compileSdk. Force every plugin
// module to compile against the same API level as the app so AAR metadata
// checks pass. Registered BEFORE evaluationDependsOn, which triggers evaluation.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt is com.android.build.gradle.BaseExtension) {
            val current = androidExt.compileSdkVersion
            val numeric = current?.removePrefix("android-")?.toIntOrNull() ?: 0
            if (numeric in 1..35) {
                androidExt.compileSdkVersion(36)
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
