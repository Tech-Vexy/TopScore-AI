val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    project.layout.buildDirectory.value(rootProject.layout.buildDirectory.dir(project.name))
}

subprojects {
    afterEvaluate {
        project.extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.apply {
            if (namespace == null) {
                namespace = project.group.toString()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}