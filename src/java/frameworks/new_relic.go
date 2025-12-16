package frameworks

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/libbuildpack"
)

// NewRelicFramework implements New Relic APM agent support
type NewRelicFramework struct {
	context *Context
}

// NewNewRelicFramework creates a new New Relic framework instance
func NewNewRelicFramework(ctx *Context) *NewRelicFramework {
	return &NewRelicFramework{context: ctx}
}

// Detect checks if New Relic should be included
func (n *NewRelicFramework) Detect() (string, error) {
	// Check for New Relic service binding
	vcapServices, err := GetVCAPServices()
	if err != nil {
		n.context.Log.Warning("Failed to parse VCAP_SERVICES: %s", err.Error())
		return "", nil
	}

	// New Relic can be bound as:
	// - "newrelic" service (marketplace or label)
	// - Services with "newrelic" tag
	// - User-provided services with "newrelic" in the name (Docker platform)
	if vcapServices.HasService("newrelic") || vcapServices.HasTag("newrelic") || vcapServices.HasServiceByNamePattern("newrelic") {
		n.context.Log.Info("New Relic service detected!")
		return "New Relic Agent", nil
	}

	// Also check for NEW_RELIC_LICENSE_KEY environment variable
	if n.context.Stager.LinkDirectoryInDepDir(filepath.Join(n.context.Stager.BuildDir(), ".new-relic-credentials"), "new-relic-credentials") == nil {
		return "New Relic Agent", nil
	}

	n.context.Log.Debug("New Relic not detected")
	return "", nil
}

// findNewRelicAgent locates the newrelic.jar in the agent directory
func (n *NewRelicFramework) findNewRelicAgent(agentDir string) (string, error) {
	// Common paths to check
	commonPaths := []string{
		filepath.Join(agentDir, "newrelic.jar"),
		filepath.Join(agentDir, "newrelic", "newrelic.jar"),
	}

	for _, path := range commonPaths {
		if _, err := os.Stat(path); err == nil {
			return path, nil
		}
	}

	// Search recursively for newrelic.jar
	var foundPath string
	filepath.Walk(agentDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if !info.IsDir() && info.Name() == "newrelic.jar" {
			foundPath = path
			return filepath.SkipAll
		}
		return nil
	})

	if foundPath != "" {
		return foundPath, nil
	}

	return "", fmt.Errorf("newrelic.jar not found in %s", agentDir)
}

// Supply installs the New Relic agent
func (n *NewRelicFramework) Supply() error {
	n.context.Log.BeginStep("Installing New Relic Agent")

	// Get New Relic agent dependency from manifest
	dep, err := n.context.Manifest.DefaultVersion("newrelic")
	if err != nil {
		n.context.Log.Warning("Unable to determine New Relic version, using default")
		dep = libbuildpack.Dependency{
			Name:    "newrelic",
			Version: "8.14.0", // Fallback version
		}
	}

	// Install New Relic agent JAR
	agentDir := filepath.Join(n.context.Stager.DepDir(), "new_relic_agent")
	if err := n.context.Installer.InstallDependency(dep, agentDir); err != nil {
		return fmt.Errorf("failed to install New Relic agent: %w", err)
	}

	n.context.Log.Info("Installed New Relic Agent version %s", dep.Version)
	return nil
}

// Finalize performs final New Relic configuration
func (n *NewRelicFramework) Finalize() error {
	// Find the actual New Relic agent jar at staging time
	agentDir := filepath.Join(n.context.Stager.DepDir(), "new_relic_agent")
	agentJarPath, err := n.findNewRelicAgent(agentDir)
	if err != nil {
		return fmt.Errorf("failed to locate newrelic.jar: %w", err)
	}

	// Build runtime path using $DEPS_DIR
	relPath, err := filepath.Rel(n.context.Stager.DepDir(), agentJarPath)
	if err != nil {
		return fmt.Errorf("failed to compute relative path: %w", err)
	}
	runtimeAgentPath := filepath.Join("$DEPS_DIR/0", relPath)

	// Add javaagent to JAVA_OPTS
	javaOpts := fmt.Sprintf("-javaagent:%s", runtimeAgentPath)

	// Get New Relic configuration from service binding
	vcapServices, _ := GetVCAPServices()
	service := vcapServices.GetService("newrelic")

	// If not found by label, try user-provided services (Docker platform)
	if service == nil {
		service = vcapServices.GetServiceByNamePattern("newrelic")
	}

	if service != nil {
		// Add license key from service credentials
		if licenseKey, ok := service.Credentials["licenseKey"].(string); ok && licenseKey != "" {
			javaOpts += fmt.Sprintf(" -Dnewrelic.config.license_key=%s", licenseKey)
		}

		// Add app name from service name
		if service.Name != "" {
			javaOpts += fmt.Sprintf(" -Dnewrelic.config.app_name='%s'", service.Name)
		}
	}

	// Write to .opts file using priority 35
	if err := writeJavaOptsFile(n.context, 35, "new_relic", javaOpts); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	n.context.Log.Info("New Relic Agent configured (priority 35)")
	return nil
}
