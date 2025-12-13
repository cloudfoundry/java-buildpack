package frameworks

import (
	"fmt"
	"os"
	"path/filepath"
)

// ContainerCustomizerFramework implements Tomcat configuration customization
// for Spring Boot WAR applications
type ContainerCustomizerFramework struct {
	context *Context
}

// NewContainerCustomizerFramework creates a new Container Customizer framework instance
func NewContainerCustomizerFramework(ctx *Context) *ContainerCustomizerFramework {
	return &ContainerCustomizerFramework{context: ctx}
}

// Detect checks if Container Customizer should be included
// Detects Spring Boot WAR files that need Tomcat customization
func (c *ContainerCustomizerFramework) Detect() (string, error) {
	buildDir := c.context.Stager.BuildDir()

	// Check if this is a Spring Boot WAR application
	// Spring Boot WAR apps have WEB-INF and BOOT-INF directories
	webInfPath := filepath.Join(buildDir, "WEB-INF")
	bootInfPath := filepath.Join(buildDir, "BOOT-INF")

	webInfStat, webInfErr := os.Stat(webInfPath)
	bootInfStat, bootInfErr := os.Stat(bootInfPath)

	// Must have both WEB-INF and BOOT-INF to be a Spring Boot WAR
	if webInfErr == nil && webInfStat.IsDir() &&
		bootInfErr == nil && bootInfStat.IsDir() {

		// Verify Spring Boot by checking for spring-boot-*.jar in lib directories
		if c.hasSpringBootJars(buildDir) {
			c.context.Log.Debug("Detected Spring Boot WAR application for Container Customizer")
			return "Container Customizer", nil
		}
	}

	return "", nil
}

// hasSpringBootJars checks if Spring Boot JARs exist in lib directories
func (c *ContainerCustomizerFramework) hasSpringBootJars(buildDir string) bool {
	libDirs := []string{
		filepath.Join(buildDir, "WEB-INF", "lib"),
		filepath.Join(buildDir, "BOOT-INF", "lib"),
	}

	for _, libDir := range libDirs {
		if _, err := os.Stat(libDir); err != nil {
			continue
		}

		entries, err := os.ReadDir(libDir)
		if err != nil {
			continue
		}

		for _, entry := range entries {
			if entry.IsDir() {
				continue
			}
			name := entry.Name()
			// Look for spring-boot-*.jar files
			if filepath.Ext(name) == ".jar" && contains(name, "spring-boot-") {
				return true
			}
		}
	}

	return false
}

// Supply installs the Container Customizer library
func (c *ContainerCustomizerFramework) Supply() error {
	c.context.Log.BeginStep("Installing Container Customizer")

	// Get container-customizer dependency from manifest
	dep, err := c.context.Manifest.DefaultVersion("container-customizer")
	if err != nil {
		return fmt.Errorf("unable to determine Container Customizer version: %w", err)
	}

	// Install Container Customizer JAR to deps directory
	customizerDir := filepath.Join(c.context.Stager.DepDir(), "container_customizer")
	if err := c.context.Installer.InstallDependency(dep, customizerDir); err != nil {
		return fmt.Errorf("failed to install Container Customizer: %w", err)
	}

	c.context.Log.Info("Installed Container Customizer version %s", dep.Version)
	return nil
}

// Finalize adds the Container Customizer JAR to the classpath
// The Container Customizer library provides hooks for external Tomcat configuration
func (c *ContainerCustomizerFramework) Finalize() error {
	// Find the installed Container Customizer JAR
	customizerDir := filepath.Join(c.context.Stager.DepDir(), "container_customizer")
	jarPattern := filepath.Join(customizerDir, "container-customizer-*.jar")

	matches, err := filepath.Glob(jarPattern)
	if err != nil || len(matches) == 0 {
		c.context.Log.Warning("Container Customizer JAR not found, skipping classpath configuration")
		return nil
	}

	// Convert staging path to runtime path for CLASSPATH
	// Staging: /tmp/staging/deps/0/container_customizer/container-customizer-2.0.0.jar
	// Runtime: $DEPS_DIR/0/container_customizer/container-customizer-2.0.0.jar
	relPath := filepath.Base(matches[0])
	runtimePath := fmt.Sprintf("$DEPS_DIR/0/container_customizer/%s", relPath)

	// Write profile.d script to add Container Customizer JAR to classpath
	// This ensures it's available to the embedded Tomcat at startup
	profileScript := fmt.Sprintf(`# Container Customizer Framework
export CLASSPATH="%s:${CLASSPATH:-}"
`, runtimePath)

	if err := c.context.Stager.WriteProfileD("container_customizer.sh", profileScript); err != nil {
		return fmt.Errorf("failed to write container_customizer.sh profile.d script: %w", err)
	}

	c.context.Log.Info("Configured Container Customizer for embedded Tomcat customization")
	c.context.Log.Debug("Container Customizer JAR will be added to classpath at runtime: %s", runtimePath)

	return nil
}
