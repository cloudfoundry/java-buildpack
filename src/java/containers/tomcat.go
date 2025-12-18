package containers

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/resources"
	"github.com/cloudfoundry/libbuildpack"
	yaml "gopkg.in/yaml.v2"
)

// TomcatContainer handles servlet/WAR applications
type TomcatContainer struct {
	context *common.Context
}

// NewTomcatContainer creates a new Tomcat container
func NewTomcatContainer(ctx *common.Context) *TomcatContainer {
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
		javaMajorVersion, versionErr := common.DetermineJavaVersion(javaHome)
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

	// Write profile.d script to set CATALINA_HOME, CATALINA_BASE, and JAVA_OPTS at runtime
	depsIdx := t.context.Stager.DepsIdx()
	tomcatPath := fmt.Sprintf("$DEPS_DIR/%s/tomcat", depsIdx)

	// Add http.port system property to JAVA_OPTS so Tomcat uses $PORT for the HTTP connector
	// Add access.logging.enabled to enable CloudFoundryAccessLoggingValve
	// These are required for Cloud Foundry where the platform assigns a dynamic port
	envContent := fmt.Sprintf(`export CATALINA_HOME=%s
export CATALINA_BASE=%s
export JAVA_OPTS="${JAVA_OPTS:+$JAVA_OPTS }-Dhttp.port=$PORT -Daccess.logging.enabled=true"
`, tomcatPath, tomcatPath)

	if err := t.context.Stager.WriteProfileD("tomcat.sh", envContent); err != nil {
		t.context.Log.Warning("Could not write tomcat.sh profile.d script: %s", err.Error())
	} else {
		t.context.Log.Debug("Created profile.d script: tomcat.sh")
	}

	// Install Tomcat support libraries (lifecycle, access-logging, and logging)
	// These are ALWAYS required for proper Tomcat initialization with Cloud Foundry
	if err := t.installTomcatLifecycleSupport(); err != nil {
		return fmt.Errorf("failed to install Tomcat lifecycle support: %w", err)
	}

	if err := t.installTomcatAccessLoggingSupport(); err != nil {
		return fmt.Errorf("failed to install Tomcat access logging support: %w", err)
	}

	loggingSupportJar, err := t.installTomcatLoggingSupport()
	if err != nil {
		return fmt.Errorf("failed to install Tomcat logging support: %w", err)
	}

	// Create setenv.sh in tomcat/bin to add logging support JAR to CLASSPATH
	// Tomcat's catalina.sh automatically sources setenv.sh if it exists
	// This ensures the logging JAR is on the classpath before Tomcat's logging initializes
	if err := t.createSetenvScript(tomcatDir, loggingSupportJar); err != nil {
		return fmt.Errorf("failed to create setenv.sh: %w", err)
	}

	// Install default Cloud Foundry-optimized Tomcat configuration (unless external config is used)
	if err := t.installDefaultConfiguration(tomcatDir); err != nil {
		return fmt.Errorf("failed to install default Tomcat configuration: %w", err)
	}

	// Install external Tomcat configuration if enabled (overrides defaults)
	if err := t.installExternalConfiguration(tomcatDir); err != nil {
		return fmt.Errorf("failed to install external Tomcat configuration: %w", err)
	}

	// JVMKill agent is installed and configured by JRE component

	return nil
}

// installTomcatLifecycleSupport installs Tomcat lifecycle support library to tomcat/lib
func (t *TomcatContainer) installTomcatLifecycleSupport() error {
	dep, err := t.context.Manifest.DefaultVersion("tomcat-lifecycle-support")
	if err != nil {
		return err
	}

	// InstallDependency for JAR files (non-archives) copies the file to the target directory
	// The JAR will be placed in tomcat/lib/ as tomcat/lib/tomcat-lifecycle-support-X.Y.Z.RELEASE.jar
	tomcatDir := filepath.Join(t.context.Stager.DepDir(), "tomcat")
	libDir := filepath.Join(tomcatDir, "lib")

	// Ensure lib directory exists
	if err := os.MkdirAll(libDir, 0755); err != nil {
		return fmt.Errorf("failed to create tomcat lib directory: %w", err)
	}

	if err := t.context.Installer.InstallDependency(dep, libDir); err != nil {
		return fmt.Errorf("failed to install Tomcat lifecycle support: %w", err)
	}

	t.context.Log.Info("Successfully installed Tomcat Lifecycle Support %s to tomcat/lib", dep.Version)
	return nil
}

// installTomcatAccessLoggingSupport installs Tomcat access logging support library to tomcat/lib
func (t *TomcatContainer) installTomcatAccessLoggingSupport() error {
	dep, err := t.context.Manifest.DefaultVersion("tomcat-access-logging-support")
	if err != nil {
		return err
	}

	// InstallDependency for JAR files (non-archives) copies the file to the target directory
	// The JAR will be placed in tomcat/lib/ as tomcat/lib/tomcat-access-logging-support-X.Y.Z.RELEASE.jar
	tomcatDir := filepath.Join(t.context.Stager.DepDir(), "tomcat")
	libDir := filepath.Join(tomcatDir, "lib")

	// Ensure lib directory exists
	if err := os.MkdirAll(libDir, 0755); err != nil {
		return fmt.Errorf("failed to create tomcat lib directory: %w", err)
	}

	if err := t.context.Installer.InstallDependency(dep, libDir); err != nil {
		return fmt.Errorf("failed to install Tomcat access logging support: %w", err)
	}

	t.context.Log.Info("Successfully installed Tomcat Access Logging Support %s to tomcat/lib", dep.Version)
	return nil
}

// installTomcatLoggingSupport installs Tomcat logging support library to tomcat/bin
// This JAR must be on the classpath BEFORE Tomcat's logging initializes
// Returns the JAR filename so it can be added to CLASSPATH in profile.d script
func (t *TomcatContainer) installTomcatLoggingSupport() (string, error) {
	dep, err := t.context.Manifest.DefaultVersion("tomcat-logging-support")
	if err != nil {
		return "", err
	}

	// InstallDependency for JAR files (non-archives) copies the file to the target directory
	// The JAR will be placed in tomcat/bin/ as tomcat/bin/tomcat-logging-support-X.Y.Z.RELEASE.jar
	tomcatDir := filepath.Join(t.context.Stager.DepDir(), "tomcat")
	binDir := filepath.Join(tomcatDir, "bin")

	// Ensure bin directory exists
	if err := os.MkdirAll(binDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create tomcat bin directory: %w", err)
	}

	if err := t.context.Installer.InstallDependency(dep, binDir); err != nil {
		return "", fmt.Errorf("failed to install Tomcat logging support: %w", err)
	}

	jarName := fmt.Sprintf("%s-%s.RELEASE.jar", dep.Name, dep.Version)
	t.context.Log.Info("Successfully installed Tomcat Logging Support %s to tomcat/bin (contains CloudFoundryConsoleHandler)", dep.Version)
	return jarName, nil
}

// createSetenvScript creates a setenv.sh script in tomcat/bin to add logging support JAR to CLASSPATH
// Tomcat's catalina.sh automatically sources setenv.sh if it exists
func (t *TomcatContainer) createSetenvScript(tomcatDir, loggingSupportJar string) error {
	binDir := filepath.Join(tomcatDir, "bin")
	setenvPath := filepath.Join(binDir, "setenv.sh")

	// Build the runtime path to the logging JAR
	// At runtime, CATALINA_HOME points to $DEPS_DIR/0/tomcat
	jarPath := "$CATALINA_HOME/bin/" + loggingSupportJar

	// Create setenv.sh content that adds logging JAR to CLASSPATH
	setenvContent := fmt.Sprintf(`#!/bin/sh
# This file is sourced by catalina.sh before starting Tomcat
# Add Tomcat logging support JAR to CLASSPATH for CloudFoundryConsoleHandler

CLASSPATH=$CLASSPATH:%s
`, jarPath)

	// Write the setenv.sh file
	if err := os.WriteFile(setenvPath, []byte(setenvContent), 0755); err != nil {
		return fmt.Errorf("failed to write setenv.sh: %w", err)
	}

	t.context.Log.Info("Created setenv.sh to add logging support JAR to CLASSPATH")
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

	// Install external configuration with strip=0 to overlay onto Tomcat directory
	// The external config archive has structure: ./conf/...
	// We extract directly to tomcatDir (no stripping needed)
	if err := t.context.Installer.InstallDependencyWithStrip(dep, tomcatDir, 0); err != nil {
		return fmt.Errorf("failed to install external configuration: %w", err)
	}

	t.context.Log.Info("Installed external Tomcat configuration version %s", dep.Version)
	return nil
}

// downloadExternalConfiguration downloads external Tomcat configuration by first fetching
// index.yml to lookup the actual download URL for the specified version
func (t *TomcatContainer) downloadExternalConfiguration(repositoryRoot, version, tomcatDir string) error {
	// Step 1: Download and parse index.yml from repository_root
	indexURL := fmt.Sprintf("%s/index.yml", repositoryRoot)
	t.context.Log.Info("Fetching external configuration index from: %s", indexURL)

	indexResp, err := http.Get(indexURL)
	if err != nil {
		return fmt.Errorf("failed to download index.yml: %w", err)
	}
	defer indexResp.Body.Close()

	if indexResp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to download index.yml: HTTP %d", indexResp.StatusCode)
	}

	// Read and parse index.yml
	indexData, err := io.ReadAll(indexResp.Body)
	if err != nil {
		return fmt.Errorf("failed to read index.yml: %w", err)
	}

	// Parse YAML as map[string]string (version -> URL)
	var index map[string]string
	if err := yaml.Unmarshal(indexData, &index); err != nil {
		return fmt.Errorf("failed to parse index.yml: %w", err)
	}

	// Step 2: Look up the download URL for the requested version
	downloadURL, found := index[version]
	if !found {
		return fmt.Errorf("version %s not found in index.yml (available versions: %v)", version, getKeys(index))
	}

	t.context.Log.Info("Found version %s in index, downloading from: %s", version, downloadURL)

	// Step 3: Download the configuration archive
	tmpFile, err := os.CreateTemp("", "tomcat-external-config-*.tar.gz")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(tmpFile.Name())
	defer tmpFile.Close()

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

	// Step 4: Extract the archive to tomcatDir with strip=0
	// The external config archive has structure: ./conf/...
	// We extract directly to tomcatDir (no stripping needed)
	t.context.Log.Info("Extracting external configuration to: %s", tomcatDir)
	if err := libbuildpack.ExtractTarGzWithStrip(tmpFile.Name(), tomcatDir, 0); err != nil {
		return fmt.Errorf("failed to extract external configuration: %w", err)
	}

	t.context.Log.Info("Successfully installed external Tomcat configuration version %s", version)
	return nil
}

// installDefaultConfiguration installs embedded Cloud Foundry-optimized Tomcat configuration
// These defaults provide proper CF integration (dynamic ports, stdout logging, X-Forwarded-* headers, etc.)
// External configuration (if enabled) will override these defaults
func (t *TomcatContainer) installDefaultConfiguration(tomcatDir string) error {
	// Check if external configuration will be used (if so, skip defaults)
	externalConfigEnabled, _, _ := t.isExternalConfigurationEnabled()
	if externalConfigEnabled {
		t.context.Log.Debug("External Tomcat configuration enabled, skipping embedded defaults")
		return nil
	}

	t.context.Log.Info("Installing Cloud Foundry-optimized Tomcat configuration defaults")

	confDir := filepath.Join(tomcatDir, "conf")
	if err := os.MkdirAll(confDir, 0755); err != nil {
		return fmt.Errorf("failed to create conf directory: %w", err)
	}

	// Install embedded configuration files
	configFiles := []string{
		"tomcat/conf/server.xml",
		"tomcat/conf/logging.properties",
		"tomcat/conf/context.xml",
	}

	for _, configFile := range configFiles {
		data, err := resources.GetResource(configFile)
		if err != nil {
			t.context.Log.Warning("Embedded config %s not found: %s", configFile, err)
			continue
		}

		targetPath := filepath.Join(confDir, filepath.Base(configFile))
		if err := os.WriteFile(targetPath, data, 0644); err != nil {
			return fmt.Errorf("failed to write %s: %w", filepath.Base(configFile), err)
		}

		t.context.Log.Info("Installed default %s to %s", filepath.Base(configFile), targetPath)
	}

	t.context.Log.Info("Tomcat configuration includes:")
	t.context.Log.Info("  - Dynamic port binding (${http.port} from $PORT)")
	t.context.Log.Info("  - HTTP/2 support enabled")
	t.context.Log.Info("  - RemoteIpValve for X-Forwarded-* headers")
	t.context.Log.Info("  - CloudFoundryAccessLoggingValve with vcap_request_id")
	t.context.Log.Info("  - Stdout logging via CloudFoundryConsoleHandler")

	return nil
}

// getKeys returns the keys of a map as a slice (for error messages)
func getKeys(m map[string]string) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
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

	// Tomcat support JARs are already installed directly to tomcat/lib during Supply phase
	// No additional configuration needed in Finalize phase

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

// configureTomcatSupport copies Tomcat lifecycle support JAR to Tomcat's lib directory
// This ensures the JAR is loaded early enough for logging initialization
// Release returns the Tomcat startup command
// Uses $CATALINA_HOME which is set by profile.d/tomcat.sh at runtime
func (t *TomcatContainer) Release() (string, error) {
	// Use $CATALINA_HOME environment variable set by profile.d script
	// Profile.d scripts run BEFORE the release command at runtime (same as $JAVA_HOME)
	cmd := "$CATALINA_HOME/bin/catalina.sh run"

	return cmd, nil
}
