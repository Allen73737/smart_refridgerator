buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.1")
    }
}

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

    project.plugins.whenPluginAdded {
        if (this.javaClass.name.contains("com.android.build.gradle.LibraryPlugin") || 
            this.javaClass.name.contains("com.android.build.gradle.AppPlugin")) {
            
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    val getNamespace = android.javaClass.methods.find { it.name == "getNamespace" }
                    val currentNamespace = getNamespace?.invoke(android)
                    if (currentNamespace == null) {
                        val setNamespace = android.javaClass.methods.find { it.name == "setNamespace" && it.parameterCount == 1 }
                        setNamespace?.invoke(android, "com.smridge.plugins.${project.name.replace("-", "_")}")
                        println("Injected namespace for ${project.name}")
                    }
                } catch (e: Exception) {
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
