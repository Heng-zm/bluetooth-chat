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

// Fix for older plugins like flutter_bluetooth_serial
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            if (android != null && (android.namespace == null || android.namespace!!.isEmpty())) {
                val name = project.name.replace("-", "_")
                android.namespace = if (name == "flutter_bluetooth_serial") {
                    "io.github.edufolly.flutter_bluetooth_serial"
                } else {
                    "com.example.$name"
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
