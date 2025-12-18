package containers

import (
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// SpringBootContainer handles Spring Boot JAR applications
type SpringBootContainer struct {
	context     *common.Context
	jarFile     string
	startScript string // For staged Spring Boot apps (bin/application)
}

// NewSpringBootContainer creates a new Spring Boot container
func NewSpringBootContainer(ctx *common.Context) *SpringBootContainer {
	return &SpringBootContainer{
		context: ctx,
	}
}

// Detect checks if this is a Spring Boot application
func (s *SpringBootContainer) Detect() (string, error) {
	buildDir := s.context.Stager.BuildDir()

	// Check for BOOT-INF directory (exploded Spring Boot JAR)
	bootInf := filepath.Join(buildDir, "BOOT-INF")
	if _, err := os.Stat(bootInf); err == nil {
		// Verify this is actually a Spring Boot application by checking MANIFEST.MF
		if s.isSpringBootExplodedJar(buildDir) {
			s.context.Log.Debug("Detected Spring Boot application via BOOT-INF directory")
			return "Spring Boot", nil
		}
		// Has BOOT-INF but not a Spring Boot app - let other containers handle it
		s.context.Log.Debug("Found BOOT-INF directory but not a Spring Boot application (missing Spring Boot manifest markers)")
	}

	// Check for Spring Boot JAR in root directory
	jarFile, err := s.findSpringBootJar(buildDir)
	if err == nil && jarFile != "" {
		s.jarFile = jarFile
		s.context.Log.Debug("Detected Spring Boot JAR: %s", jarFile)
		return "Spring Boot", nil
	}

	// Check for staged Spring Boot application (bin/ + lib/ with spring-boot-*.jar)
	// This matches Ruby buildpack's DistZipLike pattern for Spring Boot
	if s.hasSpringBootInLib(buildDir) {
		// Find the startup script in bin/ directory
		startScript, err := s.findStartupScript(buildDir)
		if err == nil && startScript != "" {
			s.startScript = startScript
			s.context.Log.Debug("Detected staged Spring Boot application via lib/ directory with script: %s", startScript)
			return "Spring Boot", nil
		}
	}

	return "", nil
}

// findSpringBootJar looks for a Spring Boot JAR in the build directory
func (s *SpringBootContainer) findSpringBootJar(buildDir string) (string, error) {
	entries, err := os.ReadDir(buildDir)
	if err != nil {
		return "", err
	}

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		name := entry.Name()
		if strings.HasSuffix(name, ".jar") {
			// Check if JAR has Spring Boot manifest
			jarPath := filepath.Join(buildDir, name)
			if s.isSpringBootJar(jarPath) {
				return filepath.Join("$HOME", name), nil
			}
		}
	}

	return "", nil
}

// isSpringBootJar checks if a JAR is a Spring Boot JAR
func (s *SpringBootContainer) isSpringBootJar(jarPath string) bool {
	// TODO: In full implementation, we'd extract and check MANIFEST.MF
	// For now, check file name patterns
	name := filepath.Base(jarPath)
	return strings.Contains(name, "spring") ||
		strings.Contains(name, "boot") ||
		strings.Contains(name, "BOOT-INF")
}

// hasSpringBootInLib checks for staged Spring Boot applications (bin/ + lib/ with spring-boot-*.jar)
// This matches Ruby buildpack's pattern where Spring Boot inherits from DistZipLike
// Checks multiple lib directories: lib/, WEB-INF/lib/, BOOT-INF/lib/
func (s *SpringBootContainer) hasSpringBootInLib(buildDir string) bool {
	// List of potential lib directories (matches Ruby buildpack's SpringBootUtils.lib() method)
	libDirs := []string{
		filepath.Join(buildDir, "lib"),
		filepath.Join(buildDir, "WEB-INF", "lib"),
		filepath.Join(buildDir, "BOOT-INF", "lib"),
	}

	for _, libDir := range libDirs {
		// Check if lib directory exists
		if _, err := os.Stat(libDir); err != nil {
			continue
		}

		// Look for spring-boot-*.jar files
		entries, err := os.ReadDir(libDir)
		if err != nil {
			continue
		}

		for _, entry := range entries {
			if entry.IsDir() {
				continue
			}

			name := entry.Name()
			// Match pattern: spring-boot-*.jar (case-insensitive check)
			if strings.HasPrefix(strings.ToLower(name), "spring-boot-") && strings.HasSuffix(name, ".jar") {
				s.context.Log.Debug("Found Spring Boot JAR in %s: %s", libDir, name)
				return true
			}
		}
	}

	return false
}

// findStartupScript looks for the startup script in bin/ directory
func (s *SpringBootContainer) findStartupScript(buildDir string) (string, error) {
	binDir := filepath.Join(buildDir, "bin")
	entries, err := os.ReadDir(binDir)
	if err != nil {
		return "", err
	}

	// Look for executable scripts (ignore .bat files)
	for _, entry := range entries {
		if !entry.IsDir() && filepath.Ext(entry.Name()) != ".bat" {
			return entry.Name(), nil
		}
	}

	return "", fmt.Errorf("no startup script found in bin/")
}

// Supply installs Spring Boot dependencies
func (s *SpringBootContainer) Supply() error {
	s.context.Log.BeginStep("Supplying Spring Boot")

	// For Spring Boot, most dependencies are already in the JAR
	// JRE installation (including JVMKill and Memory Calculator) is handled by the JRE provider

	// If this is a staged Spring Boot app with bin/ scripts, make them executable
	if s.startScript != "" {
		if err := s.makeScriptsExecutable(); err != nil {
			s.context.Log.Warning("Could not make scripts executable: %s", err.Error())
		}
	}

	return nil
}

// makeScriptsExecutable ensures all scripts in bin/ are executable
func (s *SpringBootContainer) makeScriptsExecutable() error {
	buildDir := s.context.Stager.BuildDir()
	binDir := filepath.Join(buildDir, "bin")

	entries, err := os.ReadDir(binDir)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		if !entry.IsDir() && filepath.Ext(entry.Name()) != ".bat" {
			scriptPath := filepath.Join(binDir, entry.Name())
			if err := os.Chmod(scriptPath, 0755); err != nil {
				s.context.Log.Warning("Could not make %s executable: %s", entry.Name(), err.Error())
			}
		}
	}

	return nil
}

// Finalize performs final Spring Boot configuration
func (s *SpringBootContainer) Finalize() error {
	s.context.Log.BeginStep("Finalizing Spring Boot")

	// Read existing JAVA_OPTS (set by JRE finalize phase)
	envFile := filepath.Join(s.context.Stager.DepDir(), "env", "JAVA_OPTS")
	var existingOpts string
	if data, err := os.ReadFile(envFile); err == nil {
		existingOpts = strings.TrimSpace(string(data))
	}

	// Configure additional JAVA_OPTS for Spring Boot
	additionalOpts := []string{
		"-Djava.io.tmpdir=$TMPDIR",
		"-XX:+ExitOnOutOfMemoryError",
	}

	// Combine existing opts with additional opts
	var finalOpts string
	if existingOpts != "" {
		finalOpts = existingOpts + " " + strings.Join(additionalOpts, " ")
	} else {
		finalOpts = strings.Join(additionalOpts, " ")
	}

	// Write combined JAVA_OPTS
	if err := s.context.Stager.WriteEnvFile("JAVA_OPTS", finalOpts); err != nil {
		return fmt.Errorf("failed to write JAVA_OPTS: %w", err)
	}

	return nil
}

// Release returns the Spring Boot startup command
func (s *SpringBootContainer) Release() (string, error) {
	buildDir := s.context.Stager.BuildDir()

	// Check if we have an exploded JAR (BOOT-INF directory)
	bootInf := filepath.Join(buildDir, "BOOT-INF")
	if _, err := os.Stat(bootInf); err == nil {
		// Verify this is actually a Spring Boot application
		if s.isSpringBootExplodedJar(buildDir) {
			// True Spring Boot exploded JAR - use JarLauncher
			// Determine the correct JarLauncher class name based on Spring Boot version
			jarLauncherClass := s.getJarLauncherClass(buildDir)
			// Use eval to properly handle backslash-escaped values in $JAVA_OPTS (Ruby buildpack parity)
			return fmt.Sprintf("eval exec $JAVA_HOME/bin/java $JAVA_OPTS -cp . %s", jarLauncherClass), nil
		}

		// Exploded JAR but NOT Spring Boot - use Main-Class from MANIFEST.MF
		mainClass := s.readMainClassFromManifest(buildDir)
		if mainClass != "" {
			// Use classpath from BOOT-INF/classes and BOOT-INF/lib
			// Use eval to properly handle backslash-escaped values in $JAVA_OPTS (Ruby buildpack parity)
			return fmt.Sprintf("eval exec $JAVA_HOME/bin/java $JAVA_OPTS -cp $HOME:$HOME/BOOT-INF/classes:$HOME/BOOT-INF/lib/* %s", mainClass), nil
		}

		return "", fmt.Errorf("exploded JAR found but no Main-Class in MANIFEST.MF")
	}

	// Check for staged Spring Boot app with startup script
	if s.startScript != "" {
		cmd := fmt.Sprintf("$HOME/bin/%s", s.startScript)
		return cmd, nil
	}

	// Find the Spring Boot JAR
	jarFile := s.jarFile
	if jarFile == "" {
		jar, err := s.findSpringBootJar(buildDir)
		if err != nil || jar == "" {
			return "", fmt.Errorf("no Spring Boot JAR found")
		}
		jarFile = jar
	}

	// Use eval to properly handle backslash-escaped values in $JAVA_OPTS (Ruby buildpack parity)
	cmd := fmt.Sprintf("eval exec $JAVA_HOME/bin/java $JAVA_OPTS -jar %s", jarFile)
	return cmd, nil
}

// isSpringBootExplodedJar checks if an exploded JAR is actually a Spring Boot application
// by looking for Spring Boot-specific markers in MANIFEST.MF
func (s *SpringBootContainer) isSpringBootExplodedJar(buildDir string) bool {
	manifestPath := filepath.Join(buildDir, "META-INF", "MANIFEST.MF")
	data, err := os.ReadFile(manifestPath)
	if err != nil {
		s.context.Log.Debug("Could not read MANIFEST.MF: %s", err.Error())
		return false
	}

	// Parse MANIFEST.MF and look for Spring Boot markers
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)

		// Check for Spring Boot-specific entries:
		// - Start-Class: The actual main class (Spring Boot specific)
		// - Spring-Boot-Version: Spring Boot version
		// - Spring-Boot-Classes: BOOT-INF/classes
		// - Spring-Boot-Lib: BOOT-INF/lib
		if strings.HasPrefix(line, "Start-Class:") ||
			strings.HasPrefix(line, "Spring-Boot-Version:") ||
			strings.HasPrefix(line, "Spring-Boot-Classes:") ||
			strings.HasPrefix(line, "Spring-Boot-Lib:") {
			s.context.Log.Debug("Found Spring Boot marker in MANIFEST.MF: %s", line)
			return true
		}
	}

	s.context.Log.Debug("No Spring Boot markers found in MANIFEST.MF - this is a plain exploded JAR")
	return false
}

// readMainClassFromManifest reads the Main-Class entry from MANIFEST.MF
func (s *SpringBootContainer) readMainClassFromManifest(buildDir string) string {
	manifestPath := filepath.Join(buildDir, "META-INF", "MANIFEST.MF")
	data, err := os.ReadFile(manifestPath)
	if err != nil {
		s.context.Log.Debug("Could not read MANIFEST.MF: %s", err.Error())
		return ""
	}

	// Parse MANIFEST.MF file (simple line-by-line parsing)
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "Main-Class:") {
			mainClass := strings.TrimSpace(strings.TrimPrefix(line, "Main-Class:"))
			s.context.Log.Debug("Found Main-Class in MANIFEST.MF: %s", mainClass)
			return mainClass
		}
	}

	return ""
}

// getJarLauncherClass returns the correct JarLauncher class name based on Spring Boot version
// Spring Boot 2.x uses: org.springframework.boot.loader.JarLauncher
// Spring Boot 3.x uses: org.springframework.boot.loader.launch.JarLauncher
func (s *SpringBootContainer) getJarLauncherClass(buildDir string) string {
	manifestPath := filepath.Join(buildDir, "META-INF", "MANIFEST.MF")
	data, err := os.ReadFile(manifestPath)
	if err != nil {
		s.context.Log.Debug("Could not read MANIFEST.MF for version detection: %s", err.Error())
		// Default to Spring Boot 3.x (newer) launcher
		return "org.springframework.boot.loader.launch.JarLauncher"
	}

	// Parse MANIFEST.MF to get Main-Class which tells us the actual launcher class
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "Main-Class:") {
			mainClass := strings.TrimSpace(strings.TrimPrefix(line, "Main-Class:"))
			s.context.Log.Debug("Found Main-Class in MANIFEST.MF: %s", mainClass)

			// If Main-Class is set to JarLauncher, use that exact class
			if strings.Contains(mainClass, "JarLauncher") {
				return mainClass
			}
		}
	}

	// If we couldn't determine from Main-Class, check Spring Boot version
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "Spring-Boot-Version:") {
			version := strings.TrimSpace(strings.TrimPrefix(line, "Spring-Boot-Version:"))
			s.context.Log.Debug("Found Spring-Boot-Version: %s", version)

			// Spring Boot 3.x changed the loader package structure
			if strings.HasPrefix(version, "3.") {
				return "org.springframework.boot.loader.launch.JarLauncher"
			}
			// Spring Boot 2.x uses the old loader package
			return "org.springframework.boot.loader.JarLauncher"
		}
	}

	// Default to Spring Boot 3.x (newer) launcher if version couldn't be determined
	s.context.Log.Debug("Could not determine Spring Boot version, defaulting to 3.x launcher")
	return "org.springframework.boot.loader.launch.JarLauncher"
}
