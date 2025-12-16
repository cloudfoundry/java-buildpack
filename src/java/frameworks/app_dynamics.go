package frameworks

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/libbuildpack"
)

// AppDynamicsFramework implements AppDynamics APM agent support
type AppDynamicsFramework struct {
	context *Context
}

// NewAppDynamicsFramework creates a new AppDynamics framework instance
func NewAppDynamicsFramework(ctx *Context) *AppDynamicsFramework {
	return &AppDynamicsFramework{context: ctx}
}

// Detect checks if AppDynamics should be included
func (a *AppDynamicsFramework) Detect() (string, error) {
	// Check for AppDynamics service binding
	vcapServices, err := GetVCAPServices()
	if err != nil {
		a.context.Log.Warning("Failed to parse VCAP_SERVICES: %s", err.Error())
		return "", nil
	}

	// AppDynamics can be bound as:
	// - "appdynamics" service (marketplace or label)
	// - Services with "appdynamics" tag
	// - User-provided services with "appdynamics" in the name (Docker platform)
	if vcapServices.HasService("appdynamics") || vcapServices.HasTag("appdynamics") || vcapServices.HasServiceByNamePattern("appdynamics") {
		return "AppDynamics Agent", nil
	}

	return "", nil
}

// findAppDynamicsAgent locates the javaagent.jar in the agent directory
func (a *AppDynamicsFramework) findAppDynamicsAgent(agentDir string) (string, error) {
	// Common paths to check
	commonPaths := []string{
		filepath.Join(agentDir, "javaagent.jar"),
		filepath.Join(agentDir, "ver*", "javaagent.jar"), // versioned directory pattern
	}

	for _, pattern := range commonPaths {
		matches, _ := filepath.Glob(pattern)
		if len(matches) > 0 {
			// Return first match
			if _, err := os.Stat(matches[0]); err == nil {
				return matches[0], nil
			}
		}
	}

	// Search recursively for javaagent.jar
	var foundPath string
	filepath.Walk(agentDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if !info.IsDir() && info.Name() == "javaagent.jar" {
			foundPath = path
			return filepath.SkipAll
		}
		return nil
	})

	if foundPath != "" {
		return foundPath, nil
	}

	return "", fmt.Errorf("javaagent.jar not found in %s", agentDir)
}

// Supply installs the AppDynamics agent
func (a *AppDynamicsFramework) Supply() error {
	a.context.Log.BeginStep("Installing AppDynamics Agent")

	// Get AppDynamics agent dependency from manifest
	dep, err := a.context.Manifest.DefaultVersion("appdynamics")
	if err != nil {
		a.context.Log.Warning("Unable to determine AppDynamics version, using default")
		dep = libbuildpack.Dependency{
			Name:    "appdynamics",
			Version: "24.7.0", // Fallback version
		}
	}

	// Install AppDynamics agent
	agentDir := filepath.Join(a.context.Stager.DepDir(), "app_dynamics_agent")
	if err := a.context.Installer.InstallDependency(dep, agentDir); err != nil {
		return fmt.Errorf("failed to install AppDynamics agent: %w", err)
	}

	a.context.Log.Info("Installed AppDynamics Agent version %s", dep.Version)
	return nil
}

// Finalize configures AppDynamics agent for runtime
func (a *AppDynamicsFramework) Finalize() error {

	// Find the actual AppDynamics agent jar at staging time
	agentDir := filepath.Join(a.context.Stager.DepDir(), "app_dynamics_agent")
	agentJarPath, err := a.findAppDynamicsAgent(agentDir)
	if err != nil {
		return fmt.Errorf("failed to locate javaagent.jar: %w", err)
	}
	a.context.Log.Debug("Found AppDynamics agent at: %s", agentJarPath)

	// Build runtime path using $DEPS_DIR
	relPath, err := filepath.Rel(a.context.Stager.DepDir(), agentJarPath)
	if err != nil {
		return fmt.Errorf("failed to compute relative path: %w", err)
	}
	runtimeAgentPath := filepath.Join("$DEPS_DIR/0", relPath)

	// Get AppDynamics configuration from service binding
	vcapServices, _ := GetVCAPServices()
	service := vcapServices.GetService("appdynamics")

	// If not found by label, try user-provided services (Docker platform)
	if service == nil {
		service = vcapServices.GetServiceByNamePattern("appdynamics")
	}

	// Build javaagent options with runtime path using $DEPS_DIR
	javaOpts := fmt.Sprintf("-javaagent:%s", runtimeAgentPath)

	if service != nil {
		// Add controller host
		if host, ok := service.Credentials["host-name"].(string); ok && host != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.controller.hostName=%s", host)
		}

		// Add controller port
		if port, ok := service.Credentials["port"].(string); ok && port != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.controller.port=%s", port)
		}

		// Add SSL enabled
		if ssl, ok := service.Credentials["ssl-enabled"].(string); ok && ssl != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.controller.ssl.enabled=%s", ssl)
		}

		// Add account name
		if account, ok := service.Credentials["account-name"].(string); ok && account != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.agent.accountName=%s", account)
		}

		// Add account access key
		if accessKey, ok := service.Credentials["account-access-key"].(string); ok && accessKey != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.agent.accountAccessKey=%s", accessKey)
		}

		// Add application name
		if appName, ok := service.Credentials["application-name"].(string); ok && appName != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.agent.applicationName=%s", appName)
		}

		// Add tier name (use app name from VCAP_APPLICATION if not provided)
		if tierName, ok := service.Credentials["tier-name"].(string); ok && tierName != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.agent.tierName=%s", tierName)
		}

		// Add node name (use instance index if available)
		if nodeName, ok := service.Credentials["node-name"].(string); ok && nodeName != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.agent.nodeName=%s", nodeName)
		}
	}

	// Append to JAVA_OPTS (preserves values from other frameworks)
	if err := AppendToJavaOpts(a.context, javaOpts); err != nil {
		return fmt.Errorf("failed to set JAVA_OPTS for AppDynamics: %w", err)
	}

	a.context.Log.Info("Installed AppDynamics Agent version %s", dep.Version)
	return nil
}

// Finalize performs final AppDynamics configuration
func (a *AppDynamicsFramework) Finalize() error {
	// AppDynamics doesn't require finalization
	return nil
}
