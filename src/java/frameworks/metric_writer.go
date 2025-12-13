package frameworks

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// MetricWriterFramework implements Micrometer metrics enhancement
// This framework adds CloudFoundry-specific tags to Micrometer metrics
type MetricWriterFramework struct {
	context *Context
}

// NewMetricWriterFramework creates a new Metric Writer framework instance
func NewMetricWriterFramework(ctx *Context) *MetricWriterFramework {
	return &MetricWriterFramework{context: ctx}
}

// Detect checks if Metric Writer should be included
// Detects Micrometer presence and checks if enabled
func (m *MetricWriterFramework) Detect() (string, error) {
	// Check if explicitly enabled via configuration
	if !m.isEnabled() {
		m.context.Log.Debug("Metric Writer is disabled (default)")
		return "", nil
	}

	// Check if application has Micrometer
	if !m.hasMicrometer() {
		m.context.Log.Debug("Metric Writer not applicable - no Micrometer found")
		return "", nil
	}

	m.context.Log.Debug("Detected Micrometer application for Metric Writer")
	return "Metric Writer", nil
}

// hasMicrometer checks if the application uses Micrometer
func (m *MetricWriterFramework) hasMicrometer() bool {
	buildDir := m.context.Stager.BuildDir()

	// Check common locations for micrometer-core JAR
	libDirs := []string{
		filepath.Join(buildDir, "lib"),
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
			// Look for micrometer-core-*.jar files
			if strings.HasPrefix(name, "micrometer-core-") && strings.HasSuffix(name, ".jar") {
				m.context.Log.Debug("Found Micrometer in %s: %s", libDir, name)
				return true
			}
		}
	}

	return false
}

// Supply installs the Metric Writer library
func (m *MetricWriterFramework) Supply() error {
	m.context.Log.BeginStep("Installing Metric Writer")

	// Get metric-writer dependency from manifest
	dep, err := m.context.Manifest.DefaultVersion("metric-writer")
	if err != nil {
		return fmt.Errorf("unable to determine Metric Writer version: %w", err)
	}

	// Install Metric Writer JAR to deps directory
	writerDir := filepath.Join(m.context.Stager.DepDir(), "metric_writer")
	if err := m.context.Installer.InstallDependency(dep, writerDir); err != nil {
		return fmt.Errorf("failed to install Metric Writer: %w", err)
	}

	m.context.Log.Info("Installed Metric Writer version %s", dep.Version)
	return nil
}

// Finalize adds the Metric Writer JAR to the classpath and configures CF tags
func (m *MetricWriterFramework) Finalize() error {
	// Find the installed Metric Writer JAR
	writerDir := filepath.Join(m.context.Stager.DepDir(), "metric_writer")
	jarPattern := filepath.Join(writerDir, "metric-writer-*.jar")

	matches, err := filepath.Glob(jarPattern)
	if err != nil || len(matches) == 0 {
		m.context.Log.Warning("Metric Writer JAR not found, skipping classpath configuration")
		return nil
	}

	// Convert staging path to runtime path for CLASSPATH
	relPath := filepath.Base(matches[0])
	runtimePath := fmt.Sprintf("$DEPS_DIR/0/metric_writer/%s", relPath)

	// Build CloudFoundry tag environment variables
	cfTags := m.buildCFTagEnvVars()

	// Write profile.d script to add Metric Writer JAR to classpath and set CF tags
	profileScript := fmt.Sprintf(`# Metric Writer Framework - CloudFoundry Micrometer Tags
export CLASSPATH="%s:${CLASSPATH:-}"

# CloudFoundry-specific Micrometer tags
%s
`, runtimePath, cfTags)

	if err := m.context.Stager.WriteProfileD("metric_writer.sh", profileScript); err != nil {
		return fmt.Errorf("failed to write metric_writer.sh profile.d script: %w", err)
	}

	m.context.Log.Info("Configured Metric Writer for CloudFoundry Micrometer tags")
	m.context.Log.Debug("Metric Writer JAR will be added to classpath at runtime: %s", runtimePath)

	return nil
}

// buildCFTagEnvVars constructs environment variable exports for CloudFoundry tags
// These environment variables can be overridden by user-provided values
func (m *MetricWriterFramework) buildCFTagEnvVars() string {
	var envVars []string

	// The Metric Writer library reads these environment variables to populate tags
	// Each tag has a default extraction from VCAP_APPLICATION if not explicitly set

	// cf.account - defaults to VCAP_APPLICATION.cf_api
	envVars = append(envVars, `export CF_APP_ACCOUNT="${CF_APP_ACCOUNT:-$(echo $VCAP_APPLICATION | jq -r '.cf_api // empty')}"`)

	// cf.application - defaults to VCAP_APPLICATION.application_name
	envVars = append(envVars, `export CF_APP_APPLICATION="${CF_APP_APPLICATION:-$(echo $VCAP_APPLICATION | jq -r '.application_name // empty')}"`)

	// cf.cluster - defaults to application_name (Frigga cluster extraction)
	envVars = append(envVars, `export CF_APP_CLUSTER="${CF_APP_CLUSTER:-$(echo $VCAP_APPLICATION | jq -r '.application_name // empty')}"`)

	// cf.version - defaults to application_name (Frigga revision extraction)
	envVars = append(envVars, `export CF_APP_VERSION="${CF_APP_VERSION:-$(echo $VCAP_APPLICATION | jq -r '.application_version // empty')}"`)

	// cf.instance.index - defaults to CF_INSTANCE_INDEX
	envVars = append(envVars, `export CF_APP_INSTANCE_INDEX="${CF_APP_INSTANCE_INDEX:-$CF_INSTANCE_INDEX}"`)

	// cf.organization - defaults to VCAP_APPLICATION.organization_name
	envVars = append(envVars, `export CF_APP_ORGANIZATION="${CF_APP_ORGANIZATION:-$(echo $VCAP_APPLICATION | jq -r '.organization_name // empty')}"`)

	// cf.space - defaults to VCAP_APPLICATION.space_name
	envVars = append(envVars, `export CF_APP_SPACE="${CF_APP_SPACE:-$(echo $VCAP_APPLICATION | jq -r '.space_name // empty')}"`)

	return strings.Join(envVars, "\n")
}

// isEnabled checks if Metric Writer is enabled
// Default is false (disabled) unless explicitly enabled via configuration
func (m *MetricWriterFramework) isEnabled() bool {
	// Check JBP_CONFIG_METRIC_WRITER environment variable
	config := os.Getenv("JBP_CONFIG_METRIC_WRITER")

	// Parse the config to check for enabled: true
	if config != "" {
		// Simple check: if it contains "enabled: true" or "'enabled': true"
		if contains(config, "enabled: true") || contains(config, "'enabled': true") ||
			contains(config, "enabled : true") || contains(config, "'enabled' : true") {
			return true
		}
		if contains(config, "enabled: false") || contains(config, "'enabled': false") {
			return false
		}
	}

	// Default to disabled
	return false
}
