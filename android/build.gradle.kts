allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// --- ADD THIS BLOCK BELOW ---
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application")) {
            val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            // If the namespace is missing, we inject one based on the project name
            if (android != null && android.namespace == null) {
                if (project.name == "flutter_bluetooth_serial") {
                    android.namespace = "io.github.edufolly.flutter_bluetooth_serial"
                } else {
                    // Fallback for any other old plugins: use the project name
                    android.namespace = "com.example.${project.name.replace("-", "_")}"
                }
            }
        }
    }
}
// -----------------------------

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
