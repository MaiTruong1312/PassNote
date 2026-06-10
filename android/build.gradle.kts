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
    project.evaluationDependsOn(":app")
}

subprojects {
    val project = this
    if (project.name == "isar_flutter_libs") {
        // Vá lỗi namespace cho Isar trên AGP 8.x
        plugins.withId("com.android.library") {
            val android = project.extensions.getByName("android")
            try {
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                setNamespace.invoke(android, "dev.isar.isar_flutter_libs")
            } catch (e: Exception) { }
        }
        
        // Tự động xóa trường 'package' trong Manifest để tránh xung đột với namespace
        project.tasks.whenTaskAdded {
            if (name.contains("process") && name.contains("Manifest")) {
                doFirst {
                    val manifestFile = project.file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val content = manifestFile.readText()
                        if (content.contains("package=")) {
                            manifestFile.writeText(content.replace(Regex("package=\"[^\"]*\""), ""))
                        }
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
