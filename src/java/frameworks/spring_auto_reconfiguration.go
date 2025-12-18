package frameworks

import (
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/libbuildpack"
)

// SpringAutoReconfigurationFramework implements Spring Auto-reconfiguration support for Cloud Foundry
// This framework automatically reconfigures Spring applications to use Cloud Foundry services
// DEPRECATED: This framework is disabled by default as of Dec 2025. Please migrate to java-cfenv.
// Can be re-enabled with: JBP_CONFIG_SPRING_AUTO_RECONFIGURATION='{enabled: true}'
type SpringAutoReconfigurationFramework struct {
	context *common.Context
}

// NewSpringAutoReconfigurationFramework creates a new Spring Auto-reconfiguration framework instance
func NewSpringAutoReconfigurationFramework(ctx *common.Context) *SpringAutoReconfigurationFramework {
	return &SpringAutoReconfigurationFramework{context: ctx}
}

// Detect checks if Spring Auto-reconfiguration should be included
func (s *SpringAutoReconfigurationFramework) Detect() (string, error) {
	// Check if enabled in configuration
	enabled := s.isEnabled()
	if !enabled {
		return "", nil
	}

	// Check if Spring is present
	if !s.hasSpring() {
		return "", nil
	}

	// Don't enable if java-cfenv is already present
	if s.hasJavaCfEnv() {
		s.context.Log.Debug("java-cfenv detected, skipping Spring Auto-reconfiguration")
		return "", nil
	}

	return "Spring Auto-reconfiguration", nil
}

// Supply installs the Spring Auto-reconfiguration JAR
func (s *SpringAutoReconfigurationFramework) Supply() error {
	s.context.Log.BeginStep("Installing Spring Auto-reconfiguration")

	// Log deprecation warnings
	if s.hasSpringCloudConnectors() {
		s.context.Log.Warning("ATTENTION: The Spring Cloud Connectors library is present in your application. This library " +
			"has been in maintenance mode since July 2019 and is no longer receiving updates.")
		s.context.Log.Warning("Please migrate to java-cfenv immediately. See https://via.vmw.com/EiBW for migration instructions.")
	}

	// Check again if java-cfenv framework is being installed
	if s.hasJavaCfEnv() {
		s.context.Log.Debug("java-cfenv present, skipping Spring Auto-reconfiguration installation")
		return nil
	}

	// Get Spring Auto-reconfiguration dependency from manifest
	dep, err := s.context.Manifest.DefaultVersion("auto-reconfiguration")
	if err != nil {
		s.context.Log.Warning("Unable to determine Spring Auto-reconfiguration version, using default")
		dep = libbuildpack.Dependency{
			Name:    "auto-reconfiguration",
			Version: "2.13.0", // Fallback version
		}
	}

	// Install Spring Auto-reconfiguration JAR
	autoReconfDir := filepath.Join(s.context.Stager.DepDir(), "spring_auto_reconfiguration")
	if err := s.context.Installer.InstallDependency(dep, autoReconfDir); err != nil {
		return fmt.Errorf("failed to install Spring Auto-reconfiguration: %w", err)
	}

	// The JAR will be added to classpath in finalize phase
	s.context.Log.Warning("ATTENTION: The Spring Auto Reconfiguration and shaded Spring Cloud Connectors libraries are " +
		"being installed. These projects have been deprecated and are no longer receiving updates.")
	s.context.Log.Warning("Spring Auto Reconfiguration is now DISABLED BY DEFAULT. You have explicitly enabled it via " +
		"`JBP_CONFIG_SPRING_AUTO_RECONFIGURATION='{enabled: true}'`. Please migrate to java-cfenv as soon as possible.")
	s.context.Log.Warning("For migration instructions, see https://via.vmw.com/EiBW. Once you migrate to java-cfenv, " +
		"these warnings will disappear.")

	s.context.Log.Info("Installed Spring Auto-reconfiguration version %s", dep.Version)
	return nil
}

// Finalize performs final Spring Auto-reconfiguration configuration
func (s *SpringAutoReconfigurationFramework) Finalize() error {
	// Add the JAR to additional libraries (classpath)
	autoReconfDir := filepath.Join(s.context.Stager.DepDir(), "spring_auto_reconfiguration")
	jarPattern := filepath.Join(autoReconfDir, "auto-reconfiguration-*.jar")

	matches, err := filepath.Glob(jarPattern)
	if err != nil || len(matches) == 0 {
		// JAR not found, might not have been installed
		return nil
	}

	// Add to classpath via CLASSPATH environment variable
	classpath := os.Getenv("CLASSPATH")
	if classpath != "" {
		classpath += ":"
	}
	classpath += matches[0]

	if err := s.context.Stager.WriteEnvFile("CLASSPATH", classpath); err != nil {
		return fmt.Errorf("failed to set CLASSPATH for Spring Auto-reconfiguration: %w", err)
	}

	return nil
}

// isEnabled checks if Spring Auto-reconfiguration is enabled in configuration
func (s *SpringAutoReconfigurationFramework) isEnabled() bool {
	// Check JBP_CONFIG_SPRING_AUTO_RECONFIGURATION environment variable
	config := os.Getenv("JBP_CONFIG_SPRING_AUTO_RECONFIGURATION")
	if config != "" {
		// Parse the configuration string
		// Expected format: '{enabled: true}' or '{enabled: false}'
		// Simple check: if it contains "false", it's disabled
		if strings.Contains(config, "false") {
			return false
		}
		// If it contains "true" or any other value, consider it enabled
		if strings.Contains(config, "true") {
			return true
		}
		// If config is set but doesn't contain true/false, default to disabled for safety
		return false
	}

	// Default to disabled (changed Dec 2025 - deprecated since July 2019)
	return false
}

// hasSpring checks if Spring Core is present in the application
func (s *SpringAutoReconfigurationFramework) hasSpring() bool {
	// Check common locations for spring-core*.jar
	// Note: Go's filepath.Glob does not support ** recursive patterns
	commonPaths := []string{
		filepath.Join(s.context.Stager.BuildDir(), "WEB-INF", "lib", "spring-core*.jar"),
		filepath.Join(s.context.Stager.BuildDir(), "WEB-INF", "lib", "org.springframework.spring-core*.jar"),
		filepath.Join(s.context.Stager.BuildDir(), "lib", "spring-core*.jar"),
		filepath.Join(s.context.Stager.BuildDir(), "BOOT-INF", "lib", "spring-core*.jar"),
	}

	for _, path := range commonPaths {
		matches, _ := filepath.Glob(path)
		if len(matches) > 0 {
			return true
		}
	}

	return false
}

// hasJavaCfEnv checks if java-cfenv is present in the application
func (s *SpringAutoReconfigurationFramework) hasJavaCfEnv() bool {
	// Check common locations for java-cfenv*.jar
	commonPaths := []string{
		filepath.Join(s.context.Stager.BuildDir(), "WEB-INF", "lib", "java-cfenv*.jar"),
		filepath.Join(s.context.Stager.BuildDir(), "lib", "java-cfenv*.jar"),
		filepath.Join(s.context.Stager.BuildDir(), "BOOT-INF", "lib", "java-cfenv*.jar"),
	}

	for _, path := range commonPaths {
		matches, _ := filepath.Glob(path)
		if len(matches) > 0 {
			return true
		}
	}

	// Also check if java_cf_env framework is being installed
	javaCfEnvDir := filepath.Join(s.context.Stager.DepDir(), "java_cf_env")
	if _, err := os.Stat(javaCfEnvDir); err == nil {
		return true
	}

	return false
}

// hasSpringCloudConnectors checks if Spring Cloud Connectors are present
func (s *SpringAutoReconfigurationFramework) hasSpringCloudConnectors() bool {
	// Check common locations for Spring Cloud Connectors JARs
	// Note: Go's filepath.Glob does not support ** recursive patterns
	commonPaths := []string{
		filepath.Join(s.context.Stager.BuildDir(), "WEB-INF", "lib", "spring-cloud-cloudfoundry-connector*.jar"),
		filepath.Join(s.context.Stager.BuildDir(), "WEB-INF", "lib", "spring-cloud-spring-service-connector*.jar"),
		filepath.Join(s.context.Stager.BuildDir(), "lib", "spring-cloud-cloudfoundry-connector*.jar"),
		filepath.Join(s.context.Stager.BuildDir(), "lib", "spring-cloud-spring-service-connector*.jar"),
		filepath.Join(s.context.Stager.BuildDir(), "BOOT-INF", "lib", "spring-cloud-cloudfoundry-connector*.jar"),
		filepath.Join(s.context.Stager.BuildDir(), "BOOT-INF", "lib", "spring-cloud-spring-service-connector*.jar"),
	}

	for _, path := range commonPaths {
		matches, _ := filepath.Glob(path)
		if len(matches) > 0 {
			return true
		}
	}

	return false
}
