import com.android.build.gradle.BaseExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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

// Must stay BEFORE evaluationDependsOn(":app").
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") as? BaseExtension
        if (androidExt != null) {
            // Older plugins have no `namespace`, which AGP 8+/9 requires.
            if (androidExt.namespace == null) {
                val manifest = file("src/main/AndroidManifest.xml")
                if (manifest.exists()) {
                    val pkg = Regex("package=\"([^\"]+)\"")
                        .find(manifest.readText())
                        ?.groupValues
                        ?.get(1)
                    if (pkg != null) {
                        androidExt.namespace = pkg
                    }
                }
            }

            // Same compile SDK and Java 17 for every module.
            androidExt.compileSdkVersion(36)
            androidExt.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }

    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}