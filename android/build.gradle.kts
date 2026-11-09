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
// Some older Flutter plugins (e.g. printing 5.13.x, which can't be upgraded until
// the Firebase packages are upgraded) still compile against android-30, but their
// AndroidX dependencies require compileSdk 34+. Force every plugin library to 36.
// Must be registered before the evaluationDependsOn block below.
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            extensions.getByName("android").withGroovyBuilder {
                "compileSdkVersion"(36)
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
