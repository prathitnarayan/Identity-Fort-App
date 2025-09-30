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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
// Disable unit test tasks for the flutter_plugin_android_lifecycle plugin
subprojects {
    if (name == "flutter_plugin_android_lifecycle") {
        afterEvaluate {
            tasks.matching { it.name.contains("UnitTest") }.configureEach {
                enabled = false
            }
        }
    }
}
