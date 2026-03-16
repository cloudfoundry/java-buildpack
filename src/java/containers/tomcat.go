package containers

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
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
			tomcatVersion := determineTomcatVersion(os.Getenv("JBP_CONFIG_TOMCAT"))
			t.context.Log.Debug("Detected Java major version: %d", javaMajorVersion)

			// Select Tomcat version pattern based on Java version
			var versionPattern string
			if tomcatVersion == "" {
				if javaMajorVersion >= 11 {
					// Java 11+: Use Tomcat 10.x (Jakarta EE 9+)
					versionPattern = "10.x"
					t.context.Log.Info("Using Tomcat 10.x for Java %d", javaMajorVersion)
				} else {
					// Java 8-10: Use Tomcat 9.x (Java EE 8)
					versionPattern = "9.x"
					t.context.Log.Info("Using Tomcat 9.x for Java %d", javaMajorVersion)
				}
			} else {
				versionPattern = tomcatVersion
				t.context.Log.Info("Using Tomcat %s for Java %d", versionPattern, javaMajorVersion)
			}

			if strings.HasPrefix(versionPattern, "10.") && javaMajorVersion < 11 {
				return fmt.Errorf("Tomcat 10.x requires Java 11+, but Java %d detected", javaMajorVersion)
			}

			// Resolve the version pattern to actual version using libbuildpack
			allVersions := t.context.Manifest.AllDependencyVersions("tomcat")
			resolvedVersion, err := libbuildpack.FindMatchingVersion(versionPattern, allVersions)
			if err != nil {
				return fmt.Errorf("tomcat version resolution error for pattern %q: %w", versionPattern, err)
			}

			dep.Name = "tomcat"
			dep.Version = resolvedVersion
			t.context.Log.Debug("Resolved Tomcat version pattern '%s' to %s", versionPattern, resolvedVersion)
		} else {
			t.context.Log.Warning("Unable to determine Java version: %s", versionErr.Error())
		}
	}

	// Fallback to default version if we couldn't determine Java version
	if dep.Version == "" {
		dep, err = t.context.Manifest.DefaultVersion("tomcat")
		if err != nil {
			return fmt.Errorf("failed to determine Tomcat version: no JAVA_HOME set and no default version in manifest: %w", err)
		}
	}

	// Install Tomcat with strip components to remove the top-level directory
	// Apache Tomcat tarballs extract to apache-tomcat-X.Y.Z/ subdirectory
	tomcatDir := filepath.Join(t.context.Stager.DepDir(), "tomcat")
	if err := t.context.Installer.InstallDependencyWithStrip(dep, tomcatDir, 1); err != nil {
		return fmt.Errorf("failed to install Tomcat: %w", err)
	}

	t.context.Log.Info("Installed Tomcat version %s", dep.Version)

	// Get buildpack index for multi-buildpack support
	depsIdx := t.context.Stager.DepsIdx()
	// Write profile.d script to set CATALINA_HOME, CATALINA_BASE, and JAVA_OPTS at runtime
	tomcatPath := fmt.Sprintf("$DEPS_DIR/%s/tomcat", depsIdx)

	// Determine access logging configuration (default: disabled, matching Ruby buildpack)
	// Can be enabled via: JBP_CONFIG_TOMCAT='{access_logging_support: {access_logging: enabled}}'
	accessLoggingEnabled := t.isAccessLoggingEnabled()

	// Add http.port system property to JAVA_OPTS so Tomcat uses $PORT for the HTTP connector
	// Add access.logging.enabled to control CloudFoundryAccessLoggingValve
	// These are required for Cloud Foundry where the platform assigns a dynamic port
	envContent := fmt.Sprintf(`export CATALINA_HOME=%s
export CATALINA_BASE=%s
export JAVA_OPTS="${JAVA_OPTS:+$JAVA_OPTS }-Dhttp.port=$PORT -Daccess.logging.enabled=%s"
`, tomcatPath, tomcatPath, accessLoggingEnabled)

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

	entry, err := t.context.Manifest.GetEntry(dep)
	if err != nil {
		return "", fmt.Errorf("failed to get manifest entry for tomcat-logging-support: %w", err)
	}

	jarName := filepath.Base(entry.URI)
	t.context.Log.Info("Successfully installed Tomcat Logging Support %s to tomcat/bin (contains CloudFoundryConsoleHandler)", dep.Version)
	return jarName, nil
}

// createSetenvScript creates a setenv.sh script in tomcat/bin to add logging support JAR to CLASSPATH
// Tomcat's catalina.sh automatically sources setenv.sh if it exists
func (t *TomcatContainer) createSetenvScript(tomcatDir, loggingSupportJar string) error {
	binDir := filepath.Join(tomcatDir, "bin")
	setenvPath := filepath.Join(binDir, "setenv.sh")

	jarPath := "$CATALINA_HOME/bin/" + loggingSupportJar
	// Note that Tomcat builds its own CLASSPATH env before starting. It ensures that any user defined CLASSPATH variables
	// are not used on startup, as can be seen in the catalina.sh script. That is why even we have something already
	// sourced in CLASSPATH env from profile.d scripts it is disregarded on Tomcat startup and fresh CLASSPATH env is
	// built here in the setenv.sh script.
	setenvContent := fmt.Sprintf(`#!/bin/sh
CLASSPATH="%s${CONTAINER_SECURITY_PROVIDER:+:$CONTAINER_SECURITY_PROVIDER}"
`, jarPath)

	if err := os.WriteFile(setenvPath, []byte(setenvContent), 0755); err != nil {
		return fmt.Errorf("failed to write setenv.sh: %w", err)
	}

	t.context.Log.Info("Created setenv.sh with logging JAR on boot classpath")
	return nil
}

// installExternalConfiguration installs external Tomcat configuration if enabled
func (t *TomcatContainer) installExternalConfiguration(tomcatDir string) error {
	// Check if external configuration is enabled
	externalConfigEnabled, repositoryRoot, version := t.isExternalConfigurationEnabled()

	if !externalConfigEnabled {
		t.context.Log.Debug("External Tomcat configuration is disabled, using defaults only")
		return nil
	}

	t.context.Log.Info("External Tomcat configuration is enabled, will overlay on top of defaults")

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

	t.context.Log.Info("Installed external Tomcat configuration version %s (overlaid on defaults)", dep.Version)
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

	t.context.Log.Info("Successfully installed external Tomcat configuration version %s (overlaid on defaults)", version)
	return nil
}

// installDefaultConfiguration installs embedded Cloud Foundry-optimized Tomcat configuration
// These defaults provide proper CF integration (dynamic ports, stdout logging, X-Forwarded-* headers, etc.)
// External configuration (if enabled) will be layered on top of these defaults
func (t *TomcatContainer) installDefaultConfiguration(tomcatDir string) error {
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

// DetermineTomcatVersion is an exported wrapper around determineTomcatVersion.
// It exists primarily to allow unit tests in the containers_test package to
// verify Tomcat version parsing behavior without changing production semantics.
func DetermineTomcatVersion(raw string) string {
	return determineTomcatVersion(raw)
}

// determineTomcatVersion determines the version of the tomcat
// based on the JBP_CONFIG_TOMCAT field from manifest.
// It looks for a tomcat block with a version of the form "<major>.+" (e.g. "9.+", "10.+").
// Returns "<major>.x" (e.g. "9.x", "10.x") so libbuildpack can resolve it,
func determineTomcatVersion(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}

	re := regexp.MustCompile(`(?i)tomcat\s*:\s*\{[\s\S]*?version\s*:\s*["']?([\d.]+\.\+)`)
	match := re.FindStringSubmatch(raw)
	if len(match) < 2 {
		return ""
	}

	pattern := match[1] // e.g. "9.+", "10.+", "10.23.+"

	// If it's just "<major>.+" (no additional dot), convert to "<major>.x"
	if !strings.Contains(strings.TrimSuffix(pattern, ".+"), ".") {
		// "9.+" -> "9.x"
		major := strings.TrimSuffix(pattern, ".+")
		return major + ".x"
	}

	// Otherwise, it's something like "10.23.+": pass it through unchanged
	return pattern
}

// isAccessLoggingEnabled checks if access logging is enabled in configuration
// Returns: "true" or "false" as a string (for use in JAVA_OPTS)
// Default: "false" (disabled, matching Ruby buildpack behavior)
// Can be enabled via: JBP_CONFIG_TOMCAT='{access_logging_support: {access_logging: enabled}}'
func (t *TomcatContainer) isAccessLoggingEnabled() string {
	// Check for JBP_CONFIG_TOMCAT environment variable
	configEnv := os.Getenv("JBP_CONFIG_TOMCAT")
	if configEnv != "" {
		t.context.Log.Debug("Checking access logging configuration in JBP_CONFIG_TOMCAT")

		// Look for access_logging_support section with access_logging: enabled
		// Format: {access_logging_support: {access_logging: enabled}}
		if strings.Contains(configEnv, "access_logging_support") {
			// Check if access_logging is set to enabled
			if strings.Contains(configEnv, "access_logging") &&
				(strings.Contains(configEnv, "enabled") || strings.Contains(configEnv, "true")) {
				t.context.Log.Info("Access logging enabled via JBP_CONFIG_TOMCAT")
				return "true"
			}
			// Check if explicitly disabled
			if strings.Contains(configEnv, "access_logging") &&
				(strings.Contains(configEnv, "disabled") || strings.Contains(configEnv, "false")) {
				t.context.Log.Debug("Access logging explicitly disabled via JBP_CONFIG_TOMCAT")
				return "false"
			}
		}
	}

	// Default to disabled (matches Ruby buildpack default)
	t.context.Log.Info("Access logging disabled by default (use JBP_CONFIG_TOMCAT to enable)")
	return "false"
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

func injectDocBase(xmlContent string, docBase string) string {
	idx := strings.Index(xmlContent, "<Context")
	if idx == -1 {
		return xmlContent
	}

	endIdx := strings.Index(xmlContent[idx:], ">")
	if endIdx == -1 {
		return xmlContent
	}
	endIdx += idx

	contextTag := xmlContent[idx:endIdx]

	for strings.Contains(contextTag, "docBase=") {
		docBaseIdx := strings.Index(contextTag, "docBase=")

		if docBaseIdx+8 >= len(contextTag) {
			break
		}
		quote := contextTag[docBaseIdx+8]
		if quote != '"' && quote != '\'' {
			break
		}

		endQuoteIdx := strings.Index(contextTag[docBaseIdx+9:], string(quote))
		if endQuoteIdx == -1 {
			break
		}
		endQuoteIdx += docBaseIdx + 9

		before := strings.TrimSpace(contextTag[:docBaseIdx])
		after := strings.TrimSpace(contextTag[endQuoteIdx+1:])
		if before != "" && after != "" {
			contextTag = before + " " + after
		} else {
			contextTag = before + after
		}
	}

	newContextTag := strings.Replace(contextTag, "<Context", `<Context docBase="`+docBase+`"`, 1)

	return xmlContent[:idx] + newContextTag + xmlContent[endIdx:]
}

// Finalize performs final Tomcat configuration
func (t *TomcatContainer) Finalize() error {
	t.context.Log.BeginStep("Finalizing Tomcat")

	buildDir := t.context.Stager.BuildDir()
	contextXMLPath := filepath.Join(t.context.Stager.DepDir(), "tomcat", "conf", "Catalina", "localhost", "ROOT.xml")

	webInf := filepath.Join(buildDir, "WEB-INF")
	if _, err := os.Stat(webInf); err == nil {
		// the script name is prefixed with 'zzz' as it is important to be the last script sourced from profile.d
		// so that the previous scripts assembling the CLASSPATH variable(left from frameworks) are sourced previous to it.
		if err := t.context.Stager.WriteProfileD("zzz_classpath_symlinks.sh", fmt.Sprintf(symlinkScript, filepath.Join("WEB-INF", "lib"))); err != nil {
			return fmt.Errorf("failed to write zzz_classpath_symlinks.sh: %w", err)
		}

		contextXMLDir := filepath.Dir(contextXMLPath)
		if err := os.MkdirAll(contextXMLDir, 0755); err != nil {
			return fmt.Errorf("failed to create context directory: %w", err)
		}

		appContextXML := filepath.Join(buildDir, "META-INF", "context.xml")
		var contextContent string

		if _, err := os.Stat(appContextXML); err == nil {
			xmlBytes, err := os.ReadFile(appContextXML)
			if err != nil {
				return fmt.Errorf("failed to read META-INF/context.xml: %w", err)
			}

			xmlStr := string(xmlBytes)
			xmlStr = strings.TrimSpace(xmlStr)

			contextContent = injectDocBase(xmlStr, "${user.home}/app")
			t.context.Log.Info("Merged META-INF/context.xml with ROOT.xml - realm and resource configurations preserved")
		} else {
			contextContent = fmt.Sprintf("<Context docBase=\"${user.home}/app\" reloadable=\"false\">\n</Context>\n")
			t.context.Log.Info("Created ROOT.xml with docBase pointing to application directory")
		}

		if err := os.WriteFile(contextXMLPath, []byte(contextContent), 0644); err != nil {
			return fmt.Errorf("failed to write ROOT.xml: %w", err)
		}
	}

	return nil
}

// Release returns the Tomcat startup command
func (t *TomcatContainer) Release() (string, error) {
	// Use $CATALINA_HOME environment variable set by profile.d script
	// Profile.d scripts run BEFORE the release command at runtime (same as $JAVA_HOME)
	cmd := "$CATALINA_HOME/bin/catalina.sh run"

	return cmd, nil
}
