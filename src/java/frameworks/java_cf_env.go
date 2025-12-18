package frameworks

import (
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/libbuildpack"
	"gopkg.in/yaml.v2"
)

// JavaCfEnvFramework implements java-cfenv support for Cloud Foundry
// This is the modern replacement for Spring Auto-reconfiguration
// It provides auto-configuration for Spring Boot 3.x applications
type JavaCfEnvFramework struct {
	context *common.Context
}

// NewJavaCfEnvFramework creates a new java-cfenv framework instance
func NewJavaCfEnvFramework(ctx *common.Context) *JavaCfEnvFramework {
	return &JavaCfEnvFramework{context: ctx}
}

// Detect checks if java-cfenv should be included
func (j *JavaCfEnvFramework) Detect() (string, error) {
	// Check if enabled in configuration
	enabled := j.isEnabled()
	if !enabled {
		return "", nil
	}

	// Check if Spring Boot 3.x is present
	if !j.isSpringBoot3() {
		return "", nil
	}

	// Don't enable if java-cfenv is already in the application
	if j.hasJavaCfEnv() {
		j.context.Log.Debug("java-cfenv already present in application")
		return "", nil
	}

	return "Java CF Env", nil
}

// Supply installs the java-cfenv JAR
func (j *JavaCfEnvFramework) Supply() error {
	j.context.Log.BeginStep("Installing Java CF Env")

	// Get java-cfenv dependency from manifest
	dep, err := j.context.Manifest.DefaultVersion("java-cfenv")
	if err != nil {
		j.context.Log.Warning("Unable to determine Java CF Env version, using default")
		dep = libbuildpack.Dependency{
			Name:    "java-cfenv",
			Version: "3.1.0", // Fallback version
		}
	}

	// Install java-cfenv JAR
	javaCfEnvDir := filepath.Join(j.context.Stager.DepDir(), "java_cf_env")
	if err := j.context.Installer.InstallDependency(dep, javaCfEnvDir); err != nil {
		return fmt.Errorf("failed to install Java CF Env: %w", err)
	}

	j.context.Log.Info("Installed Java CF Env version %s", dep.Version)
	return nil
}

// Finalize performs final java-cfenv configuration
func (j *JavaCfEnvFramework) Finalize() error {
	// Add the JAR to additional libraries (classpath)
	javaCfEnvDir := filepath.Join(j.context.Stager.DepDir(), "java_cf_env")
	jarPattern := filepath.Join(javaCfEnvDir, "java-cfenv-*.jar")

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

	if err := j.context.Stager.WriteEnvFile("CLASSPATH", classpath); err != nil {
		return fmt.Errorf("failed to set CLASSPATH for Java CF Env: %w", err)
	}

	return nil
}

// isEnabled checks if java-cfenv is enabled in configuration
func (j *JavaCfEnvFramework) isEnabled() bool {
	// Check JBP_CONFIG_JAVA_CF_ENV environment variable
	configOverride := os.Getenv("JBP_CONFIG_JAVA_CF_ENV")
	if configOverride != "" {
		// Parse YAML configuration
		var yamlContent interface{}
		if err := yaml.Unmarshal([]byte(configOverride), &yamlContent); err != nil {
			j.context.Log.Warning("Failed to parse JBP_CONFIG_JAVA_CF_ENV, treating as enabled: %s", err)
			return true
		}

		// Handle both direct map and string-encoded YAML
		var configData []byte
		switch v := yamlContent.(type) {
		case string:
			configData = []byte(v)
		case map[interface{}]interface{}:
			var err error
			configData, err = yaml.Marshal(v)
			if err != nil {
				j.context.Log.Warning("Failed to marshal config, treating as enabled: %s", err)
				return true
			}
		default:
			j.context.Log.Warning("Unexpected YAML type, treating as enabled: %T", v)
			return true
		}

		// Parse into config structure
		var config struct {
			Enabled bool `yaml:"enabled"`
		}
		if err := yaml.Unmarshal(configData, &config); err != nil {
			j.context.Log.Warning("Failed to parse config structure, treating as enabled: %s", err)
			return true
		}

		return config.Enabled
	}

	// Default to enabled
	return true
}

// isSpringBoot3 checks if the application is Spring Boot 3.x
func (j *JavaCfEnvFramework) isSpringBoot3() bool {
	// Look for Spring Boot 3.x JARs
	// Spring Boot 3.x uses spring-boot-3.*.jar
	patterns := []string{
		filepath.Join(j.context.Stager.BuildDir(), "**", "spring-boot-3.*.jar"),
		filepath.Join(j.context.Stager.BuildDir(), "WEB-INF", "lib", "spring-boot-3.*.jar"),
		filepath.Join(j.context.Stager.BuildDir(), "BOOT-INF", "lib", "spring-boot-3.*.jar"),
		filepath.Join(j.context.Stager.BuildDir(), "lib", "spring-boot-3.*.jar"),
	}

	for _, pattern := range patterns {
		matches, err := filepath.Glob(pattern)
		if err == nil && len(matches) > 0 {
			return true
		}
	}

	// Also check META-INF/MANIFEST.MF for Spring-Boot-Version
	manifestPath := filepath.Join(j.context.Stager.BuildDir(), "META-INF", "MANIFEST.MF")
	if content, err := os.ReadFile(manifestPath); err == nil {
		manifest := string(content)
		if strings.Contains(manifest, "Spring-Boot-Version: 3.") {
			return true
		}
	}

	return false
}

// hasJavaCfEnv checks if java-cfenv is already present in the application
func (j *JavaCfEnvFramework) hasJavaCfEnv() bool {
	// Look for java-cfenv*.jar in the application
	patterns := []string{
		filepath.Join(j.context.Stager.BuildDir(), "**", "java-cfenv*.jar"),
		filepath.Join(j.context.Stager.BuildDir(), "WEB-INF", "lib", "java-cfenv*.jar"),
		filepath.Join(j.context.Stager.BuildDir(), "BOOT-INF", "lib", "java-cfenv*.jar"),
		filepath.Join(j.context.Stager.BuildDir(), "lib", "java-cfenv*.jar"),
	}

	for _, pattern := range patterns {
		matches, err := filepath.Glob(pattern)
		if err == nil && len(matches) > 0 {
			return true
		}
	}

	return false
}
