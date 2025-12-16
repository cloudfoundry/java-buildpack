package frameworks

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/libbuildpack"
)

// JacocoAgentFramework implements JaCoCo code coverage agent support
type JacocoAgentFramework struct {
	context *Context
}

// NewJacocoAgentFramework creates a new JaCoCo agent framework instance
func NewJacocoAgentFramework(ctx *Context) *JacocoAgentFramework {
	return &JacocoAgentFramework{context: ctx}
}

// Detect checks if JaCoCo agent should be included
func (j *JacocoAgentFramework) Detect() (string, error) {
	// Check for JaCoCo service binding
	vcapServices, err := GetVCAPServices()
	if err != nil {
		j.context.Log.Warning("Failed to parse VCAP_SERVICES: %s", err.Error())
		return "", nil
	}

	// JaCoCo can be bound as:
	// - Services with "jacoco" in the label
	// - Services with "jacoco" tag
	// - User-provided services with "jacoco" in the name
	// Must have "address" credential
	if vcapServices.HasService("jacoco") || vcapServices.HasTag("jacoco") || vcapServices.HasServiceByNamePattern("jacoco") {
		service := vcapServices.GetService("jacoco")
		if service == nil {
			service = vcapServices.GetServiceByNamePattern("jacoco")
		}

		// Verify "address" credential exists (required for JaCoCo)
		if service != nil {
			if _, hasAddress := service.Credentials["address"]; hasAddress {
				j.context.Log.Info("JaCoCo service detected with address!")
				return "JaCoCo Agent", nil
			}
		}
	}

	j.context.Log.Debug("JaCoCo not detected")
	return "", nil
}

// Supply installs the JaCoCo agent
func (j *JacocoAgentFramework) Supply() error {
	j.context.Log.BeginStep("Installing JaCoCo Agent")

	// Get JaCoCo agent dependency from manifest
	dep, err := j.context.Manifest.DefaultVersion("jacoco")
	if err != nil {
		j.context.Log.Warning("Unable to determine JaCoCo version, using default")
		dep = libbuildpack.Dependency{
			Name:    "jacoco",
			Version: "0.8.12", // Fallback version
		}
	}

	// Install JaCoCo agent ZIP
	agentDir := filepath.Join(j.context.Stager.DepDir(), "jacoco_agent")
	if err := j.context.Installer.InstallDependency(dep, agentDir); err != nil {
		return fmt.Errorf("failed to install JaCoCo agent: %w", err)
	}

	j.context.Log.Info("Installed JaCoCo Agent version %s", dep.Version)
	return nil
}

// findJacocoAgent locates the jacocoagent.jar file in the installation directory
func (j *JacocoAgentFramework) findJacocoAgent(installDir string) (string, error) {
	// Check common locations first
	commonPaths := []string{
		filepath.Join(installDir, "jacocoagent.jar"),
		filepath.Join(installDir, "lib", "jacocoagent.jar"),
	}

	for _, path := range commonPaths {
		if path == "" {
			continue
		}
		if _, err := os.Stat(path); err == nil {
			return path, nil
		}
	}

	// Search recursively for nested directories
	var foundPath string
	filepath.Walk(installDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // Continue walking on errors
		}
		if !info.IsDir() && info.Name() == "jacocoagent.jar" {
			// Found the agent JAR
			foundPath = path
			return filepath.SkipAll
		}
		return nil
	})

	if foundPath != "" {
		return foundPath, nil
	}

	return "", fmt.Errorf("jacocoagent.jar not found in %s", installDir)
}

// Finalize configures the JaCoCo agent for runtime
func (j *JacocoAgentFramework) Finalize() error {
	// Get JaCoCo service credentials
	vcapServices, err := GetVCAPServices()
	if err != nil {
		return fmt.Errorf("failed to parse VCAP_SERVICES: %w", err)
	}

	service := vcapServices.GetService("jacoco")
	if service == nil {
		service = vcapServices.GetServiceByNamePattern("jacoco")
	}

	if service == nil {
		return fmt.Errorf("JaCoCo service binding not found")
	}

	credentials := service.Credentials

	// Build javaagent properties
	properties := make(map[string]string)

	// Required properties
	if address, ok := credentials["address"].(string); ok {
		properties["address"] = address
	} else {
		return fmt.Errorf("JaCoCo service binding missing required 'address' credential")
	}

	// Default output mode
	properties["output"] = "tcpclient"

	// Session ID based on CF instance GUID
	properties["sessionid"] = "$CF_INSTANCE_GUID"

	// Optional properties from service credentials
	if excludes, ok := credentials["excludes"].(string); ok && excludes != "" {
		properties["excludes"] = excludes
	}

	if includes, ok := credentials["includes"].(string); ok && includes != "" {
		properties["includes"] = includes
	}

	if port, ok := credentials["port"].(string); ok && port != "" {
		properties["port"] = port
	}

	if output, ok := credentials["output"].(string); ok && output != "" {
		properties["output"] = output
	}

	// Find jacocoagent.jar at staging time to determine relative path
	agentDir := filepath.Join(j.context.Stager.DepDir(), "jacoco_agent")
	agentJar, err := j.findJacocoAgent(agentDir)
	if err != nil {
		return fmt.Errorf("failed to locate jacocoagent.jar: %w", err)
	}
	j.context.Log.Debug("Found JaCoCo agent at: %s", agentJar)

	// Build runtime path using $DEPS_DIR
	relPath, err := filepath.Rel(j.context.Stager.DepDir(), agentJar)
	if err != nil {
		return fmt.Errorf("failed to compute relative path: %w", err)
	}
	runtimeAgentPath := filepath.Join("$DEPS_DIR/0", relPath)

	// Build javaagent option with runtime path
	javaagentOpts := fmt.Sprintf("-javaagent:%s", runtimeAgentPath)

	// Append properties as key=value pairs separated by commas
	first := true
	for key, value := range properties {
		if first {
			javaagentOpts += fmt.Sprintf("=%s=%s", key, value)
			first = false
		} else {
			javaagentOpts += fmt.Sprintf(",%s=%s", key, value)
		}
	}

	// Write to .opts file using priority 26
	if err := writeJavaOptsFile(j.context, 26, "jacoco", javaagentOpts); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	j.context.Log.Info("JaCoCo Agent configured (priority 26)")
	return nil
}
