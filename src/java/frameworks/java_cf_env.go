package frameworks

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/java-buildpack/src/java/common"

	"github.com/cloudfoundry/libbuildpack"
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

	// Check if Spring Boot 3.x/4.x is present
	if !j.isSpringBootMajor(4) && !j.isSpringBootMajor(3) {
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

	dependency := "java-cfenv"
	defaultVersion := "4.0.0"
	versionPattern := "4.x.x"

	if j.isSpringBootMajor(3) {
		defaultVersion = "3.1.0"
		versionPattern = "3.x.x"
	}

	allVersions := j.context.Manifest.AllDependencyVersions(dependency)
	resolvedVersion, err := libbuildpack.FindMatchingVersion(versionPattern, allVersions)

	dep := libbuildpack.Dependency{Name: dependency, Version: resolvedVersion}
	if err != nil {
		j.context.Log.Warning("Unable to determine Java CF Env version for pattern %s, using default", versionPattern)
		dep = libbuildpack.Dependency{
			Name:    dependency,
			Version: defaultVersion,
		}
	} else {
		j.context.Log.Debug("Resolved Java CF Env version pattern '%s' to %s", versionPattern, resolvedVersion)
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

	depsIdx := j.context.Stager.DepsIdx()
	runtimePath := fmt.Sprintf("$DEPS_DIR/%s/java_cf_env/%s", depsIdx, filepath.Base(matches[0]))

	profileScript := fmt.Sprintf("export CLASSPATH=\"%s${CLASSPATH:+:$CLASSPATH}\"\n", runtimePath)
	if err := j.context.Stager.WriteProfileD("java_cf_env.sh", profileScript); err != nil {
		return fmt.Errorf("failed to write java_cf_env.sh profile.d script: %w", err)
	}

	j.context.Log.Debug("Java CF Env JAR will be added to classpath at runtime: %s", runtimePath)

	return nil
}

// isEnabled checks if java-cfenv is enabled in configuration
func (j *JavaCfEnvFramework) isEnabled() bool {
	// Check JBP_CONFIG_JAVA_CF_ENV environment variable
	yamlHandler := common.YamlHandler{}
	configOverride := os.Getenv("JBP_CONFIG_JAVA_CF_ENV")
	if configOverride != "" {
		// Parse YAML configuration
		var yamlContent interface{}
		if err := yamlHandler.Unmarshal([]byte(configOverride), &yamlContent); err != nil {
			j.context.Log.Warning("Failed to parse JBP_CONFIG_JAVA_CF_ENV, treating as enabled: %s", err)
			return true
		}

		// Handle both direct map and string-encoded YAML
		var configData []byte
		switch v := yamlContent.(type) {
		case string:
			configData = []byte(v)
		case map[string]interface{}:
			var err error
			configData, err = yamlHandler.Marshal(v)
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
		if err := yamlHandler.Unmarshal(configData, &config); err != nil {
			j.context.Log.Warning("Failed to parse config structure, treating as enabled: %s", err)
			return true
		}

		return config.Enabled
	}

	// Default to enabled
	return true
}

// isSpringBootMajor checks if the application is Spring Boot <major>.x
func (j *JavaCfEnvFramework) isSpringBootMajor(major int) bool {
	jarGlob := fmt.Sprintf("spring-boot-%d.*.jar", major)
	patterns := []string{
		filepath.Join(j.context.Stager.BuildDir(), "**", jarGlob),
		filepath.Join(j.context.Stager.BuildDir(), "WEB-INF", "lib", jarGlob),
		filepath.Join(j.context.Stager.BuildDir(), "BOOT-INF", "lib", jarGlob),
		filepath.Join(j.context.Stager.BuildDir(), "lib", jarGlob),
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
		if strings.Contains(manifest, fmt.Sprintf("Spring-Boot-Version: %d.", major)) {
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
