package frameworks

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// ContainerSecurityProviderFramework implements container-based security provider support
// This framework provides CloudFoundryContainerProvider for Java security integration
type ContainerSecurityProviderFramework struct {
	context *Context
}

// NewContainerSecurityProviderFramework creates a new container security provider framework instance
func NewContainerSecurityProviderFramework(ctx *Context) *ContainerSecurityProviderFramework {
	return &ContainerSecurityProviderFramework{context: ctx}
}

// Detect checks if container security provider should be included
// Enabled by default, can be disabled via configuration
func (c *ContainerSecurityProviderFramework) Detect() (string, error) {
	// Enabled by default to provide container-based security
	return "Container Security Provider", nil
}

// Supply installs the container security provider JAR
func (c *ContainerSecurityProviderFramework) Supply() error {
	c.context.Log.BeginStep("Installing Container Security Provider")

	// Get container-security-provider dependency from manifest
	dep, err := c.context.Manifest.DefaultVersion("container-security-provider")
	if err != nil {
		return fmt.Errorf("unable to determine Container Security Provider version: %w", err)
	}

	// Install container security provider JAR
	providerDir := filepath.Join(c.context.Stager.DepDir(), "container_security_provider")
	if err := c.context.Installer.InstallDependency(dep, providerDir); err != nil {
		return fmt.Errorf("failed to install Container Security Provider: %w", err)
	}

	c.context.Log.Info("Installed Container Security Provider version %s", dep.Version)
	return nil
}

// Finalize configures the container security provider for runtime
func (c *ContainerSecurityProviderFramework) Finalize() error {
	// Find the installed JAR
	providerDir := filepath.Join(c.context.Stager.DepDir(), "container_security_provider")
	jarPattern := filepath.Join(providerDir, "container-security-provider-*.jar")

	matches, err := filepath.Glob(jarPattern)
	if err != nil || len(matches) == 0 {
		// JAR not found, might not have been installed
		return nil
	}

	// Get just the filename for runtime path construction
	jarFilename := filepath.Base(matches[0])

	// Detect Java version to determine extension mechanism
	// Java 9+ uses root libraries (-Xbootclasspath/a), Java 8 uses extension directories
	javaVersion, err := c.getJavaMajorVersion()
	if err != nil {
		c.context.Log.Warning("Unable to detect Java version, assuming Java 8: %s", err.Error())
		javaVersion = 8
	}

	// Build JAVA_OPTS with runtime paths using $DEPS_DIR
	var javaOpts string
	if javaVersion >= 9 {
		// Java 9+: Add to bootstrap classpath via -Xbootclasspath/a
		runtimeJarPath := fmt.Sprintf("$DEPS_DIR/0/container_security_provider/%s", jarFilename)
		javaOpts = fmt.Sprintf("-Xbootclasspath/a:%s", runtimeJarPath)
	} else {
		// Java 8: Use extension directory
		runtimeProviderDir := "$DEPS_DIR/0/container_security_provider"
		javaOpts = fmt.Sprintf("-Djava.ext.dirs=%s:$JAVA_HOME/jre/lib/ext:$JAVA_HOME/lib/ext", runtimeProviderDir)
	}

	// Add security provider to java.security.properties
	// Insert at position 1 (after default providers)
	runtimeSecurityFile := "$DEPS_DIR/0/container_security_provider/java.security"
	securityProvider := fmt.Sprintf("-Djava.security.properties=%s", runtimeSecurityFile)
	javaOpts += " " + securityProvider

	// Write security properties file
	if err := c.writeSecurityProperties(); err != nil {
		return fmt.Errorf("failed to write security properties: %w", err)
	}

	// Add key manager and trust manager configuration if specified
	keyManagerEnabled := c.getKeyManagerEnabled()
	if keyManagerEnabled != "" {
		javaOpts += fmt.Sprintf(" -Dorg.cloudfoundry.security.keymanager.enabled=%s", keyManagerEnabled)
	}

	trustManagerEnabled := c.getTrustManagerEnabled()
	if trustManagerEnabled != "" {
		javaOpts += fmt.Sprintf(" -Dorg.cloudfoundry.security.trustmanager.enabled=%s", trustManagerEnabled)
	}

	// Append to JAVA_OPTS (preserves values from other frameworks)
	if err := AppendToJavaOpts(c.context, javaOpts); err != nil {
		return fmt.Errorf("failed to set JAVA_OPTS for Container Security Provider: %w", err)
	}

	return nil
}

// writeSecurityProperties writes the java.security properties file with CloudFoundryContainerProvider
// It reads existing security providers from the JRE and inserts CloudFoundryContainerProvider at position 1
func (c *ContainerSecurityProviderFramework) writeSecurityProperties() error {
	providerDir := filepath.Join(c.context.Stager.DepDir(), "container_security_provider")
	securityFile := filepath.Join(providerDir, "java.security")

	// Read existing security providers from JRE's java.security file
	existingProviders, err := c.readExistingSecurityProviders()
	if err != nil {
		c.context.Log.Warning("Unable to read existing security providers, using defaults: %s", err)
		existingProviders = c.getDefaultSecurityProviders()
	}

	// Build security provider configuration
	// Insert CloudFoundryContainerProvider at position 1, followed by existing providers
	var content string
	content += "security.provider.1=org.cloudfoundry.security.CloudFoundryContainerProvider\n"

	// Add existing providers starting at position 2
	for i, provider := range existingProviders {
		content += fmt.Sprintf("security.provider.%d=%s\n", i+2, provider)
	}

	if err := os.WriteFile(securityFile, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write security properties file: %w", err)
	}

	return nil
}

// readExistingSecurityProviders reads security providers from the JRE's java.security file
func (c *ContainerSecurityProviderFramework) readExistingSecurityProviders() ([]string, error) {
	javaHome := os.Getenv("JAVA_HOME")
	if javaHome == "" {
		return nil, fmt.Errorf("JAVA_HOME not set")
	}

	// Try Java 9+ location first (conf/security/java.security)
	javaSecurityPath := filepath.Join(javaHome, "conf", "security", "java.security")
	if _, err := os.Stat(javaSecurityPath); os.IsNotExist(err) {
		// Fall back to Java 8 location (jre/lib/security/java.security or lib/security/java.security)
		javaSecurityPath = filepath.Join(javaHome, "lib", "security", "java.security")
		if _, err := os.Stat(javaSecurityPath); os.IsNotExist(err) {
			javaSecurityPath = filepath.Join(javaHome, "jre", "lib", "security", "java.security")
		}
	}

	content, err := os.ReadFile(javaSecurityPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read %s: %w", javaSecurityPath, err)
	}

	return c.parseSecurityProviders(string(content)), nil
}

// parseSecurityProviders extracts security.provider.N entries from java.security content
func (c *ContainerSecurityProviderFramework) parseSecurityProviders(content string) []string {
	var providers []string
	lines := strings.Split(content, "\n")

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "security.provider.") && strings.Contains(line, "=") {
			parts := strings.SplitN(line, "=", 2)
			if len(parts) == 2 {
				provider := strings.TrimSpace(parts[1])
				if provider != "" {
					providers = append(providers, provider)
				}
			}
		}
	}

	return providers
}

// getDefaultSecurityProviders returns default security providers for OpenJDK/HotSpot
func (c *ContainerSecurityProviderFramework) getDefaultSecurityProviders() []string {
	return []string{
		"sun.security.provider.Sun",
		"sun.security.rsa.SunRsaSign",
		"sun.security.ec.SunEC",
		"com.sun.net.ssl.internal.ssl.Provider",
		"com.sun.crypto.provider.SunJCE",
		"sun.security.jgss.SunProvider",
		"com.sun.security.sasl.Provider",
		"org.jcp.xml.dsig.internal.dom.XMLDSigRI",
		"sun.security.smartcardio.SunPCSC",
	}
}

// getJavaMajorVersion detects the Java major version from JAVA_HOME
func (c *ContainerSecurityProviderFramework) getJavaMajorVersion() (int, error) {
	// Check if JAVA_HOME is set
	javaHome := os.Getenv("JAVA_HOME")
	if javaHome == "" {
		return 0, fmt.Errorf("JAVA_HOME not set")
	}

	// Read release file
	releaseFile := filepath.Join(javaHome, "release")
	content, err := os.ReadFile(releaseFile)
	if err != nil {
		return 0, fmt.Errorf("failed to read release file: %w", err)
	}

	// Parse JAVA_VERSION from release file
	version := parseJavaVersion(string(content))
	if version == 0 {
		return 0, fmt.Errorf("unable to parse Java version")
	}

	return version, nil
}

// getKeyManagerEnabled returns the key_manager_enabled configuration value
func (c *ContainerSecurityProviderFramework) getKeyManagerEnabled() string {
	config := os.Getenv("JBP_CONFIG_CONTAINER_SECURITY_PROVIDER")
	if config == "" {
		return ""
	}

	// Parse configuration for key_manager_enabled
	// Format: {key_manager_enabled: true} or {'key_manager_enabled': 'true'}
	if contains(config, "key_manager_enabled") {
		if contains(config, "true") {
			return "true"
		}
		if contains(config, "false") {
			return "false"
		}
	}

	return ""
}

// getTrustManagerEnabled returns the trust_manager_enabled configuration value
func (c *ContainerSecurityProviderFramework) getTrustManagerEnabled() string {
	config := os.Getenv("JBP_CONFIG_CONTAINER_SECURITY_PROVIDER")
	if config == "" {
		return ""
	}

	// Parse configuration for trust_manager_enabled
	// Format: {trust_manager_enabled: true} or {'trust_manager_enabled': 'true'}
	if contains(config, "trust_manager_enabled") {
		if contains(config, "true") {
			return "true"
		}
		if contains(config, "false") {
			return "false"
		}
	}

	return ""
}

// parseJavaVersion parses Java major version from release file content
func parseJavaVersion(content string) int {
	// Look for JAVA_VERSION="1.8.0_..." or JAVA_VERSION="11.0...."
	lines := splitByNewline(content)
	for _, line := range lines {
		if contains(line, "JAVA_VERSION=") {
			// Extract version string
			start := stringIndexOf(line, "\"")
			if start == -1 {
				continue
			}
			end := stringIndexOf(line[start+1:], "\"")
			if end == -1 {
				continue
			}
			version := line[start+1 : start+1+end]

			// Parse major version
			if stringStartsWith(version, "1.8") {
				return 8
			}
			if stringStartsWith(version, "1.7") {
				return 7
			}

			// Java 9+ format: "11.0.1" or "17.0.1"
			dotIndex := stringIndexOf(version, ".")
			if dotIndex > 0 {
				major := version[:dotIndex]
				if majorVersion, err := strconv.Atoi(major); err == nil {
					return majorVersion
				}
			}
		}
	}

	return 0
}

// Helper functions for string manipulation
func splitByNewline(s string) []string {
	var lines []string
	start := 0
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' {
			lines = append(lines, s[start:i])
			start = i + 1
		}
	}
	if start < len(s) {
		lines = append(lines, s[start:])
	}
	return lines
}

func stringIndexOf(s, substr string) int {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return i
		}
	}
	return -1
}

func stringStartsWith(s, prefix string) bool {
	if len(s) < len(prefix) {
		return false
	}
	return s[:len(prefix)] == prefix
}
