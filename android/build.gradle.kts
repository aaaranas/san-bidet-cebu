allprojects {
    repositories {
        google()
        mavenCentral()
        // Mapbox SDK downloads — authenticated with a secret "sk." token.
        // Set MAPBOX_DOWNLOADS_TOKEN in ~/.gradle/gradle.properties (preferred,
        // keeps the secret out of the repo) or as an environment variable.
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication { create<BasicAuthentication>("basic") }
            credentials {
                username = "mapbox"
                password = (project.findProperty("MAPBOX_DOWNLOADS_TOKEN") as String?)
                    ?: System.getenv("MAPBOX_DOWNLOADS_TOKEN") ?: ""
            }
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
