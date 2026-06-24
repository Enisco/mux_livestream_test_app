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

subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            val lib = extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
            if (lib?.namespace == null) {
                val manifest = file("src/main/AndroidManifest.xml")
                if (manifest.exists()) {
                    val ns = Regex("""package="([^"]+)"""")
                        .find(manifest.readText())?.groupValues?.get(1)
                    if (ns != null) lib?.namespace = ns
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
