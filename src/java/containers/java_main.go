package containers

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// JavaMainContainer handles standalone JAR applications with a main class
type JavaMainContainer struct {
	context   *Context
	mainClass string
	jarFile   string
}

// NewJavaMainContainer creates a new Java Main container
func NewJavaMainContainer(ctx *Context) *JavaMainContainer {
	return &JavaMainContainer{
		context: ctx,
	}
}

// Detect checks if this is a Java Main application
func (j *JavaMainContainer) Detect() (string, error) {
	buildDir := j.context.Stager.BuildDir()

	// Look for JAR files with Main-Class manifest
	mainClass, jarFile := j.findMainClass(buildDir)
	if mainClass != "" {
		j.mainClass = mainClass
		j.jarFile = jarFile
		j.context.Log.Debug("Detected Java Main application: %s (main: %s)", jarFile, mainClass)
		return "Java Main", nil
	}

	// Check for META-INF/MANIFEST.MF with Main-Class
	manifestPath := filepath.Join(buildDir, "META-INF", "MANIFEST.MF")
	if _, err := os.Stat(manifestPath); err == nil {
		// Read manifest for Main-Class
		if mainClass := j.readMainClassFromManifest(manifestPath); mainClass != "" {
			j.mainClass = mainClass
			j.context.Log.Debug("Detected Java Main application via MANIFEST.MF: %s", mainClass)
			return "Java Main", nil
		}
	}

	// Check for compiled .class files
	classFiles, err := filepath.Glob(filepath.Join(buildDir, "*.class"))
	if err == nil && len(classFiles) > 0 {
		j.context.Log.Debug("Detected compiled Java classes")
		return "Java Main", nil
	}

	return "", nil
}

// findMainClass searches for a JAR with a Main-Class manifest entry
func (j *JavaMainContainer) findMainClass(buildDir string) (string, string) {
	entries, err := os.ReadDir(buildDir)
	if err != nil {
		return "", ""
	}

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		name := entry.Name()
		if strings.HasSuffix(name, ".jar") {
			// TODO: In full implementation, extract and read MANIFEST.MF
			// For now, assume any JAR could be a main JAR
			return "Main", filepath.Join("$HOME", name)
		}
	}

	return "", ""
}

// readMainClassFromManifest reads the Main-Class from a manifest file
func (j *JavaMainContainer) readMainClassFromManifest(manifestPath string) string {
	data, err := os.ReadFile(manifestPath)
	if err != nil {
		return ""
	}

	// Parse MANIFEST.MF file (simple line-by-line parsing)
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "Main-Class:") {
			mainClass := strings.TrimSpace(strings.TrimPrefix(line, "Main-Class:"))
			return mainClass
		}
	}

	return ""
}

// Supply installs Java Main dependencies
func (j *JavaMainContainer) Supply() error {
	j.context.Log.BeginStep("Supplying Java Main")

	// For Java Main apps, we need to:
	// 1. Ensure all JARs are available
	// 2. Set up classpath
	// 3. Install support utilities

	// Note: JVMKill agent is installed by the JRE component (src/java/jres/jvmkill.go)
	// No need to install it here to avoid duplication

	return nil
}

// Finalize performs final Java Main configuration
func (j *JavaMainContainer) Finalize() error {
	j.context.Log.BeginStep("Finalizing Java Main")

	// Build classpath
	classpath, err := j.buildClasspath()
	if err != nil {
		return fmt.Errorf("failed to build classpath: %w", err)
	}

	// Write CLASSPATH environment variable
	if err := j.context.Stager.WriteEnvFile("CLASSPATH", classpath); err != nil {
		return fmt.Errorf("failed to write CLASSPATH: %w", err)
	}

	// Note: JAVA_OPTS (including JVMKill agent) is configured by the JRE component
	// via profile.d/java_opts.sh. No need to configure it here to avoid duplication.

	return nil
}

// buildClasspath builds the classpath for the application
func (j *JavaMainContainer) buildClasspath() (string, error) {
	buildDir := j.context.Stager.BuildDir()

	var classpathEntries []string

	// Add current directory
	classpathEntries = append(classpathEntries, ".")

	// Check for BOOT-INF directory (exploded JAR layout)
	// Even if it's not a Spring Boot app, we need to include these paths
	bootInfClasses := filepath.Join(buildDir, "BOOT-INF", "classes")
	if _, err := os.Stat(bootInfClasses); err == nil {
		classpathEntries = append(classpathEntries, "BOOT-INF/classes")
	}

	bootInfLib := filepath.Join(buildDir, "BOOT-INF", "lib")
	if _, err := os.Stat(bootInfLib); err == nil {
		classpathEntries = append(classpathEntries, "BOOT-INF/lib/*")
	}

	// Add all JARs in the build directory
	jarFiles, err := filepath.Glob(filepath.Join(buildDir, "*.jar"))
	if err == nil {
		for _, jar := range jarFiles {
			classpathEntries = append(classpathEntries, filepath.Base(jar))
		}
	}

	// Add lib directory if it exists
	libDir := filepath.Join(buildDir, "lib")
	if _, err := os.Stat(libDir); err == nil {
		classpathEntries = append(classpathEntries, "lib/*")
	}

	return strings.Join(classpathEntries, ":"), nil
}

// Release returns the Java Main startup command
func (j *JavaMainContainer) Release() (string, error) {
	// Determine the main class to run
	mainClass := j.mainClass
	if mainClass == "" {
		// Try to detect from environment or configuration
		mainClass = os.Getenv("JAVA_MAIN_CLASS")
		if mainClass == "" {
			return "", fmt.Errorf("no main class specified (set JAVA_MAIN_CLASS)")
		}
	}

	var cmd string
	if j.jarFile != "" {
		// Run from JAR
		// Use eval to properly handle backslash-escaped values in $JAVA_OPTS (Ruby buildpack parity)
		cmd = fmt.Sprintf("eval exec $JAVA_HOME/bin/java $JAVA_OPTS -jar %s", j.jarFile)
	} else {
		// Build classpath and embed it directly in the command
		// (Don't rely on $CLASSPATH environment variable)
		classpath, err := j.buildClasspath()
		if err != nil {
			return "", fmt.Errorf("failed to build classpath: %w", err)
		}
		// Use eval to properly handle backslash-escaped values in $JAVA_OPTS (Ruby buildpack parity)
		cmd = fmt.Sprintf("eval exec $JAVA_HOME/bin/java $JAVA_OPTS -cp %s %s", classpath, mainClass)
	}

	return cmd, nil
}
