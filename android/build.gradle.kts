allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // Force transitive deps that url_launcher / share_plus pull in to stay
    // within the version ceiling of AGP 8.6.0. Without this, androidx.browser
    // 1.9.0 and core-ktx 1.17.0 are resolved, both of which require AGP ≥8.9.1.
    configurations.all {
        resolutionStrategy {
            force("androidx.browser:browser:1.8.0")
            force("androidx.core:core:1.15.0")
            force("androidx.core:core-ktx:1.15.0")
        }
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
