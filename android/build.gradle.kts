buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.20")
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
    if (project.name == "file_picker") {
        project.plugins.apply("org.jetbrains.kotlin.android")
    }
    afterEvaluate {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                val method = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                method.invoke(android, 35)
            } catch (e: Exception) {
                try {
                    val method = android.javaClass.getMethod("compileSdkVersion", java.lang.Integer::class.java)
                    method.invoke(android, 35)
                } catch (ex: Exception) {
                    // Ignore
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
