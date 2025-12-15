package containers

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/java-buildpack/src/java/jres"
	"github.com/cloudfoundry/libbuildpack"
)

// TomcatContainer handles servlet/WAR applications
type TomcatContainer struct {
	context *Context
}

// NewTomcatContainer creates a new Tomcat container
func NewTomcatContainer(ctx *Context) *TomcatContainer {
	return &TomcatContainer{
		context: ctx,
	}
}

// Detect checks if this is a Tomcat/servlet application
func (t *TomcatContainer) Detect() (string, error) {
	buildDir := t.context.Stager.BuildDir()

	// Check for WEB-INF directory (exploded WAR)
	webInf := filepath.Join(buildDir, "WEB-INF")
	if _, err := os.Stat(webInf); err == nil {
		t.context.Log.Debug("Detected WAR application via WEB-INF directory")
		return "Tomcat", nil
	}

	// Check for WAR files
	matches, err := filepath.Glob(filepath.Join(buildDir, "*.war"))
	if err == nil && len(matches) > 0 {
		t.context.Log.Debug("Detected WAR file: %s", matches[0])
		return "Tomcat", nil
	}

	return "", nil
}

// Supply installs Tomcat and dependencies
func (t *TomcatContainer) Supply() error {
	t.context.Log.BeginStep("Supplying Tomcat")

	// Determine Java version to select appropriate Tomcat version
	// Tomcat 10.x requires Java 11+, Tomcat 9.x supports Java 8-22
	javaHome := os.Getenv("JAVA_HOME")
	var dep libbuildpack.Dependency
	var err error

	if javaHome != "" {
		javaMajorVersion, versionErr := jres.DetermineJavaVersion(javaHome)
		if versionErr == nil {
			t.context.Log.Debug("Detected Java major version: %d", javaMajorVersion)

			// Select Tomcat version pattern based on Java version
			var versionPattern string
			if javaMajorVersion >= 11 {
				// Java 11+: Use Tomcat 10.x (Jakarta EE 9+)
				versionPattern = "10.x"
				t.context.Log.Info("Using Tomcat 10.x for Java %d", javaMajorVersion)
			} else {
				// Java 8-10: Use Tomcat 9.x (Java EE 8)
				versionPattern = "9.x"
				t.context.Log.Info("Using Tomcat 9.x for Java %d", javaMajorVersion)
			}

			// Resolve the version pattern to actual version using libbuildpack
			allVersions := t.context.Manifest.AllDependencyVersions("tomcat")
			resolvedVersion, err := libbuildpack.FindMatchingVersion(versionPattern, allVersions)
			if err == nil {
				dep.Name = "tomcat"
				dep.Version = resolvedVersion
				t.context.Log.Debug("Resolved Tomcat version pattern '%s' to %s", versionPattern, resolvedVersion)
			} else {
				t.context.Log.Warning("Unable to resolve Tomcat version pattern '%s': %s", versionPattern, err.Error())
			}
		} else {
			t.context.Log.Warning("Unable to determine Java version: %s", versionErr.Error())
		}
	}

	// Fallback to default version if we couldn't determine Java version
	if dep.Version == "" {
		dep, err = t.context.Manifest.DefaultVersion("tomcat")
		if err != nil {
			t.context.Log.Warning("Unable to determine default Tomcat version")
			// Final fallback to a known version
			dep.Name = "tomcat"
			dep.Version = "9.0.98"
		}
	}

	// Install Tomcat with strip components to remove the top-level directory
	// Apache Tomcat tarballs extract to apache-tomcat-X.Y.Z/ subdirectory
	tomcatDir := filepath.Join(t.context.Stager.DepDir(), "tomcat")
	if err := t.context.Installer.InstallDependencyWithStrip(dep, tomcatDir, 1); err != nil {
		return fmt.Errorf("failed to install Tomcat: %w", err)
	}

	t.context.Log.Info("Installed Tomcat version %s", dep.Version)

	// Write profile.d script to set CATALINA_HOME and CATALINA_BASE at runtime
	depsIdx := t.context.Stager.DepsIdx()
	tomcatPath := fmt.Sprintf("$DEPS_DIR/%s/tomcat", depsIdx)

	envContent := fmt.Sprintf(`export CATALINA_HOME=%s
export CATALINA_BASE=%s
`, tomcatPath, tomcatPath)

	if err := t.context.Stager.WriteProfileD("tomcat.sh", envContent); err != nil {
		t.context.Log.Warning("Could not write tomcat.sh profile.d script: %s", err.Error())
	} else {
		t.context.Log.Debug("Created profile.d script: tomcat.sh")
	}

	// Install Tomcat support libraries
	if err := t.installTomcatSupport(); err != nil {
		t.context.Log.Warning("Could not install Tomcat support: %s", err.Error())
	}

	// Install external Tomcat configuration if enabled
	if err := t.installExternalConfiguration(tomcatDir); err != nil {
		return fmt.Errorf("failed to install external Tomcat configuration: %w", err)
	}

	// JVMKill agent is installed and configured by JRE component

	return nil
}

// installTomcatSupport installs Tomcat support libraries
func (t *TomcatContainer) installTomcatSupport() error {
	dep, err := t.context.Manifest.DefaultVersion("tomcat-lifecycle-support")
	if err != nil {
		return err
	}

	supportDir := filepath.Join(t.context.Stager.DepDir(), "tomcat-lifecycle-support")
	if err := t.context.Installer.InstallDependency(dep, supportDir); err != nil {
		return fmt.Errorf("failed to install Tomcat support: %w", err)
	}

	t.context.Log.Info("Installed Tomcat Lifecycle Support version %s", dep.Version)
	return nil
}

// installExternalConfiguration installs external Tomcat configuration if enabled
func (t *TomcatContainer) installExternalConfiguration(tomcatDir string) error {
	// Check if external configuration is enabled
	externalConfigEnabled, repositoryRoot, version := t.isExternalConfigurationEnabled()

	if !externalConfigEnabled {
		t.context.Log.Debug("External Tomcat configuration is disabled")
		return nil
	}

	t.context.Log.Info("External Tomcat configuration is enabled")

	if repositoryRoot == "" {
		t.context.Log.Warning("External configuration enabled but repository_root not set")
		t.context.Log.Warning("To use external Tomcat configuration, you must:")
		t.context.Log.Warning("  1. Fork this buildpack and add external config to manifest.yml")
		t.context.Log.Warning("  2. Or use a custom buildpack with external configuration included")
		return nil
	}

	if version == "" {
		version = "1.0.0" // default version
	}

	t.context.Log.Info("External configuration repository: %s (version: %s)", repositoryRoot, version)

	// Try to install from manifest first if available
	// This will work if the user has added the external configuration to their forked buildpack manifest
	dep, err := t.context.Manifest.DefaultVersion("tomcat-external-configuration")
	if err != nil {
		// Manifest entry not found - download directly from repository_root
		t.context.Log.Info("External configuration not in manifest, downloading directly from repository")
		return t.downloadExternalConfiguration(repositoryRoot, version, tomcatDir)
	}

	t.context.Log.Info("Downloading external Tomcat configuration version %s from manifest", dep.Version)

	// Install external configuration with strip=1 to overlay onto Tomcat directory
	// The external config archive has structure: tomcat/conf/...
	// We strip the top-level "tomcat/" directory and extract directly to tomcatDir
	if err := t.context.Installer.InstallDependencyWithStrip(dep, tomcatDir, 1); err != nil {
		return fmt.Errorf("failed to install external configuration: %w", err)
	}

	t.context.Log.Info("Installed external Tomcat configuration version %s", dep.Version)
	return nil
}

// downloadExternalConfiguration downloads external Tomcat configuration directly from a URL
func (t *TomcatContainer) downloadExternalConfiguration(repositoryRoot, version, tomcatDir string) error {
	// Construct download URL
	downloadURL := fmt.Sprintf("%s/tomcat-external-configuration-%s.tar.gz", repositoryRoot, version)
	t.context.Log.Info("Downloading external configuration from: %s", downloadURL)

	// Create temporary file for download
	tmpFile, err := os.CreateTemp("", "tomcat-external-config-*.tar.gz")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(tmpFile.Name())
	defer tmpFile.Close()

	// Download the archive
	resp, err := http.Get(downloadURL)
	if err != nil {
		return fmt.Errorf("failed to download external configuration: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to download external configuration: HTTP %d", resp.StatusCode)
	}

	// Write response to temp file
	if _, err := io.Copy(tmpFile, resp.Body); err != nil {
		return fmt.Errorf("failed to write external configuration to temp file: %w", err)
	}
	tmpFile.Close()

	// Extract the archive to tomcatDir with strip=1
	// The external config archive has structure: tomcat/conf/...
	// We strip the top-level "tomcat/" directory and extract directly to tomcatDir
	t.context.Log.Info("Extracting external configuration to: %s", tomcatDir)
	if err := libbuildpack.ExtractTarGzWithStrip(tmpFile.Name(), tomcatDir, 1); err != nil {
		return fmt.Errorf("failed to extract external configuration: %w", err)
	}

	t.context.Log.Info("Successfully installed external Tomcat configuration version %s", version)
	return nil
}

// isExternalConfigurationEnabled checks if external configuration is enabled in config
// Returns: (enabled bool, repositoryRoot string, version string)
func (t *TomcatContainer) isExternalConfigurationEnabled() (bool, string, string) {
	// Read buildpack configuration from environment or config file
	// The libbuildpack Stager provides access to buildpack config

	// Check for JBP_CONFIG_TOMCAT environment variable
	configEnv := os.Getenv("JBP_CONFIG_TOMCAT")
	if configEnv != "" {
		// Parse the configuration to check external_configuration_enabled
		// For now, we'll do a simple string check
		// A full implementation would parse the YAML/JSON
		t.context.Log.Debug("JBP_CONFIG_TOMCAT: %s", configEnv)

		// Simple check for external_configuration_enabled: true
		if strings.Contains(configEnv, "external_configuration_enabled") &&
			(strings.Contains(configEnv, "true") || strings.Contains(configEnv, "True")) {

			// Extract repository_root and version if present
			repositoryRoot := extractRepositoryRoot(configEnv)
			version := extractVersion(configEnv)
			return true, repositoryRoot, version
		}
	}

	// Default to false (disabled)
	return false, "", ""
}

// extractRepositoryRoot extracts the repository_root value from config string
func extractRepositoryRoot(config string) string {
	// Simple extraction - look for repository_root: "value"
	// This is a basic implementation; a full parser would use YAML/JSON libraries

	// Look for repository_root: "..."
	if idx := strings.Index(config, "repository_root"); idx != -1 {
		remaining := config[idx:]
		// Find the opening quote
		if startQuote := strings.Index(remaining, "\""); startQuote != -1 {
			remaining = remaining[startQuote+1:]
			// Find the closing quote
			if endQuote := strings.Index(remaining, "\""); endQuote != -1 {
				return remaining[:endQuote]
			}
		}
	}

	return ""
}

// extractVersion extracts the version value from config string
func extractVersion(config string) string {
	// Look for version: "value" in the external_configuration section
	// This is a basic implementation; a full parser would use YAML/JSON libraries

	// Find external_configuration section first
	if idx := strings.Index(config, "external_configuration"); idx != -1 {
		remaining := config[idx:]
		// Look for version: "..."
		if versionIdx := strings.Index(remaining, "version"); versionIdx != -1 {
			remaining = remaining[versionIdx:]
			// Find the opening quote
			if startQuote := strings.Index(remaining, "\""); startQuote != -1 {
				remaining = remaining[startQuote+1:]
				// Find the closing quote
				if endQuote := strings.Index(remaining, "\""); endQuote != -1 {
					return remaining[:endQuote]
				}
			}
		}
	}

	return ""
}

// Finalize performs final Tomcat configuration
func (t *TomcatContainer) Finalize() error {
	t.context.Log.BeginStep("Finalizing Tomcat")

	buildDir := t.context.Stager.BuildDir()
	tomcatDir := filepath.Join(t.context.Stager.DepDir(), "tomcat")

	// Check if we have an exploded WAR (WEB-INF directory in BuildDir)
	webInf := filepath.Join(buildDir, "WEB-INF")
	if _, err := os.Stat(webInf); err == nil {
		// Configure Tomcat to serve the application from BuildDir
		// This follows the immutable BuildDir pattern: application stays where deployed
		t.context.Log.Info("Configuring Tomcat to serve exploded WAR from BuildDir")

		// Create a custom context.xml file that points to BuildDir
		// At runtime, $HOME will resolve to the application directory
		if err := t.configureContextDocBase(tomcatDir); err != nil {
			return fmt.Errorf("failed to configure Tomcat context: %w", err)
		}

		t.context.Log.Info("Tomcat configured to serve application from $HOME (BuildDir)")
	}

	// Configure Tomcat support JAR in common classpath
	if err := t.configureTomcatSupport(tomcatDir); err != nil {
		t.context.Log.Warning("Could not configure Tomcat support: %s", err.Error())
	}

	// JVMKill agent is configured by JRE component in JAVA_OPTS

	return nil
}

// configureContextDocBase creates a context configuration that points to BuildDir
func (t *TomcatContainer) configureContextDocBase(tomcatHome string) error {
	// Create conf/Catalina/localhost directory if it doesn't exist
	contextDir := filepath.Join(tomcatHome, "conf", "Catalina", "localhost")
	if err := os.MkdirAll(contextDir, 0755); err != nil {
		return fmt.Errorf("failed to create context directory: %w", err)
	}

	// Create ROOT.xml context file
	// This tells Tomcat to serve the ROOT webapp from BuildDir (the application directory)
	// Tomcat supports ${propertyName} syntax for system properties in context.xml
	contextFile := filepath.Join(contextDir, "ROOT.xml")
	contextXML := `<?xml version="1.0" encoding="UTF-8"?>
<Context docBase="${user.home}/app" reloadable="false">
    <!-- Application served from BuildDir (/home/vcap/app), not moved to DepDir -->
    <!-- At runtime: user.home system property = /home/vcap, so we use ${user.home}/app -->
</Context>
`

	if err := os.WriteFile(contextFile, []byte(contextXML), 0644); err != nil {
		return fmt.Errorf("failed to write context file: %w", err)
	}

	t.context.Log.Debug("Created Tomcat context configuration: %s", contextFile)
	return nil
}

// configureTomcatSupport adds Tomcat support JAR to common classpath
func (t *TomcatContainer) configureTomcatSupport(tomcatHome string) error {
	supportDir := filepath.Join(t.context.Stager.DepDir(), "tomcat-lifecycle-support")

	// Check if support was installed
	if _, err := os.Stat(supportDir); os.IsNotExist(err) {
		return nil // Support not installed, skip
	}

	// Find the support JAR
	matches, err := filepath.Glob(filepath.Join(supportDir, "*.jar"))
	if err != nil || len(matches) == 0 {
		return fmt.Errorf("tomcat support JAR not found in %s", supportDir)
	}

	supportJar := matches[0]

	// Create setenv.sh to add support JAR to classpath
	// This follows Tomcat's standard configuration mechanism
	binDir := filepath.Join(tomcatHome, "bin")
	setenvFile := filepath.Join(binDir, "setenv.sh")

	// Calculate runtime path to support JAR (relative to CATALINA_BASE)
	// At runtime: $CATALINA_BASE = /home/vcap/deps/0/tomcat/...
	// Support JAR is at: /home/vcap/deps/0/tomcat-lifecycle-support/...
	relPath, err := filepath.Rel(tomcatHome, supportJar)
	if err != nil {
		// If we can't calculate relative path, use absolute reference
		relPath = fmt.Sprintf("$CATALINA_BASE/../tomcat-lifecycle-support/%s", filepath.Base(supportJar))
	} else {
		relPath = fmt.Sprintf("$CATALINA_BASE/%s", relPath)
	}

	setenvContent := fmt.Sprintf(`#!/bin/bash
# Add Tomcat Lifecycle Support to classpath
export CLASSPATH="%s:$CLASSPATH"
`, relPath)

	if err := os.WriteFile(setenvFile, []byte(setenvContent), 0755); err != nil {
		return fmt.Errorf("failed to write setenv.sh: %w", err)
	}

	t.context.Log.Debug("Configured Tomcat support JAR in setenv.sh")
	return nil
}

// Release returns the Tomcat startup command
// Uses $CATALINA_HOME which is set by profile.d/tomcat.sh at runtime
func (t *TomcatContainer) Release() (string, error) {
	// Use $CATALINA_HOME environment variable set by profile.d script
	// Profile.d scripts run BEFORE the release command at runtime (same as $JAVA_HOME)
	cmd := "$CATALINA_HOME/bin/catalina.sh run"

	return cmd, nil
}
