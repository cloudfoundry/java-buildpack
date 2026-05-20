package containers

import (
	"archive/zip"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
)

type javaMainConfig struct {
	JavaMainClass string `yaml:"java_main_class"`
	Arguments     string `yaml:"arguments"`
}

func loadJavaMainConfig(log interface{ Warning(string, ...interface{}) }) javaMainConfig {
	cfg := javaMainConfig{}
	raw := os.Getenv("JBP_CONFIG_JAVA_MAIN")
	if raw == "" {
		return cfg
	}
	yamlHandler := common.YamlHandler{}
	if err := yamlHandler.ValidateFields([]byte(raw), &cfg); err != nil {
		log.Warning("Unknown JBP_CONFIG_JAVA_MAIN values: %s", err.Error())
	}
	_ = yamlHandler.Unmarshal([]byte(raw), &cfg)
	return cfg
}

// JavaMainContainer handles standalone JAR applications with a main class
type JavaMainContainer struct {
	context   *common.Context
	mainClass string
	jarFile   string
}

// NewJavaMainContainer creates a new Java Main container
func NewJavaMainContainer(ctx *common.Context) *JavaMainContainer {
	return &JavaMainContainer{
		context: ctx,
	}
}

// Detect checks if this is a Java Main application
func (j *JavaMainContainer) Detect() (string, error) {
	buildDir := j.context.Stager.BuildDir()

	// JBP_CONFIG_JAVA_MAIN with java_main_class always wins (Ruby parity)
	cfg := loadJavaMainConfig(j.context.Log)
	if cfg.JavaMainClass != "" {
		j.mainClass = cfg.JavaMainClass
		j.context.Log.Debug("Detected Java Main application via JBP_CONFIG_JAVA_MAIN: %s", j.mainClass)
		return "Java Main", nil
	}

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

// findMainClass searches for a JAR in buildDir whose META-INF/MANIFEST.MF
// contains a Main-Class entry. Returns the main class name and the path to
// the JAR (relative to $HOME) if found, or empty strings if none qualify.
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
		if !strings.HasSuffix(name, ".jar") {
			continue
		}

		jarPath := filepath.Join(buildDir, name)
		if mainClass := readMainClassFromJar(jarPath); mainClass != "" {
			return mainClass, filepath.Join("$HOME", name)
		}
	}

	return "", ""
}

// readMainClassFromJar opens a JAR (zip) file and reads the Main-Class
// attribute from META-INF/MANIFEST.MF, returning "" if not present or on error.
func readMainClassFromJar(jarPath string) string {
	r, err := zip.OpenReader(jarPath)
	if err != nil {
		return ""
	}
	defer r.Close()

	for _, f := range r.File {
		if f.Name != "META-INF/MANIFEST.MF" {
			continue
		}

		rc, err := f.Open()
		if err != nil {
			return ""
		}

		data, err := io.ReadAll(rc)
		rc.Close()
		if err != nil {
			return ""
		}

		return parseMainClass(string(data))
	}

	return ""
}

// readMainClassFromManifest reads the Main-Class from a manifest file
func (j *JavaMainContainer) readMainClassFromManifest(manifestPath string) string {
	data, err := os.ReadFile(manifestPath)
	if err != nil {
		return ""
	}

	return parseMainClass(string(data))
}

// parseMainClass extracts the Main-Class value from MANIFEST.MF content.
// Handles line continuations (lines starting with a space are folded onto the previous line).
func parseMainClass(content string) string {
	// Unfold continuation lines (space at start of line means continuation)
	content = strings.ReplaceAll(content, "\r\n", "\n")
	var unfolded strings.Builder
	for _, line := range strings.Split(content, "\n") {
		if strings.HasPrefix(line, " ") {
			unfolded.WriteString(strings.TrimPrefix(line, " "))
		} else {
			unfolded.WriteString("\n")
			unfolded.WriteString(line)
		}
	}

	for _, line := range strings.Split(unfolded.String(), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "Main-Class:") {
			return strings.TrimSpace(strings.TrimPrefix(line, "Main-Class:"))
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

// isSpringBootLauncher returns true if the given class is one of the Spring Boot launchers.
func isSpringBootLauncher(mainClass string) bool {
	switch mainClass {
	case "org.springframework.boot.loader.JarLauncher",
		"org.springframework.boot.loader.WarLauncher",
		"org.springframework.boot.loader.PropertiesLauncher",
		"org.springframework.boot.loader.launch.JarLauncher",
		"org.springframework.boot.loader.launch.WarLauncher",
		"org.springframework.boot.loader.launch.PropertiesLauncher":
		return true
	}
	return false
}

// Finalize performs final Java Main configuration
func (j *JavaMainContainer) Finalize() error {
	j.context.Log.BeginStep("Finalizing Java Main")

	// Build classpath
	classpath, err := j.buildClasspath()
	if err != nil {
		return fmt.Errorf("failed to build classpath: %w", err)
	}

	profileScript := fmt.Sprintf("export CLASSPATH=\"%s${CLASSPATH:+:$CLASSPATH}\"\n", classpath)

	// Ruby parity: set SERVER_PORT=$PORT when the main class is a Spring Boot launcher
	// so the app binds to the CF-assigned port.
	cfg := loadJavaMainConfig(j.context.Log)
	mainClass := cfg.JavaMainClass
	if mainClass == "" {
		mainClass = j.mainClass
	}
	if isSpringBootLauncher(mainClass) {
		profileScript += "export SERVER_PORT=$PORT\n"
	}

	if err := j.context.Stager.WriteProfileD("java_main.sh", profileScript); err != nil {
		return fmt.Errorf("failed to write java_main.sh profile.d script: %w", err)
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
		classpathEntries = append(classpathEntries, "$HOME/BOOT-INF/classes")
	}

	bootInfLib := filepath.Join(buildDir, "BOOT-INF", "lib")
	if _, err := os.Stat(bootInfLib); err == nil {
		classpathEntries = append(classpathEntries, "$HOME/BOOT-INF/lib/*")
	}

	// Add all JARs in the build directory
	jarFiles, err := filepath.Glob(filepath.Join(buildDir, "$HOME/*.jar"))
	if err == nil {
		for _, jar := range jarFiles {
			classpathEntries = append(classpathEntries, filepath.Base(jar))
		}
	}

	// Add lib directory if it exists
	libDir := filepath.Join(buildDir, "lib")
	if _, err := os.Stat(libDir); err == nil {
		classpathEntries = append(classpathEntries, "$HOME/lib/*")
	}

	return strings.Join(classpathEntries, ":"), nil
}

// Release returns the Java Main startup command
func (j *JavaMainContainer) Release() (string, error) {
	cfg := loadJavaMainConfig(j.context.Log)

	args := ""
	if cfg.Arguments != "" {
		args = " " + cfg.Arguments
	}

	// JBP_CONFIG_JAVA_MAIN java_main_class takes precedence over manifest Main-Class.
	// Use classpath mode so the configured class is actually invoked (not the manifest's).
	if cfg.JavaMainClass != "" {
		return fmt.Sprintf("eval exec $JAVA_HOME/bin/java $JAVA_OPTS -cp ${CLASSPATH}${CONTAINER_SECURITY_PROVIDER:+:$CONTAINER_SECURITY_PROVIDER} %s%s", cfg.JavaMainClass, args), nil
	}

	if j.jarFile != "" {
		// JAR has its own Main-Class in the manifest — java -jar handles it
		// Use eval to properly handle backslash-escaped values in $JAVA_OPTS (Ruby buildpack parity)
		return fmt.Sprintf("eval exec $JAVA_HOME/bin/java $JAVA_OPTS -jar %s%s", j.jarFile, args), nil
	}

	// Classpath mode: need an explicit main class
	mainClass := j.mainClass
	if mainClass == "" {
		mainClass = os.Getenv("JAVA_MAIN_CLASS")
		if mainClass == "" {
			return "", fmt.Errorf("no main class specified (set JAVA_MAIN_CLASS)")
		}
		j.context.Log.Debug("Main Class %s found in JAVA_MAIN_CLASS", mainClass)
	}

	// Use eval to properly handle backslash-escaped values in $JAVA_OPTS (Ruby buildpack parity)
	return fmt.Sprintf("eval exec $JAVA_HOME/bin/java $JAVA_OPTS -cp ${CLASSPATH}${CONTAINER_SECURITY_PROVIDER:+:$CONTAINER_SECURITY_PROVIDER} %s%s", mainClass, args), nil
}
