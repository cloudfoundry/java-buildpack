package frameworks

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// ContrastSecurityAgentFramework represents the Contrast Security Agent framework
type ContrastSecurityAgentFramework struct {
	context      *Context
	agentJarPath string
	configPath   string
	credentials  map[string]interface{}
}

// NewContrastSecurityAgentFramework creates a new instance of ContrastSecurityAgentFramework
func NewContrastSecurityAgentFramework(ctx *Context) *ContrastSecurityAgentFramework {
	return &ContrastSecurityAgentFramework{context: ctx}
}

// Detect determines if Contrast Security service is bound
func (c *ContrastSecurityAgentFramework) Detect() (string, error) {
	vcapServices, err := GetVCAPServices()
	if err != nil {
		return "", nil
	}

	// Check for Contrast Security service binding
	if vcapServices.HasService("contrast-security") ||
		vcapServices.HasTag("contrast-security") ||
		vcapServices.HasServiceByNamePattern("contrast-security") ||
		vcapServices.HasServiceByNamePattern("contrast") {
		return "contrast-security", nil
	}

	return "", nil
}

// findContrastAgent locates the Contrast Security agent JAR in the install directory
func (c *ContrastSecurityAgentFramework) findContrastAgent(frameworkDir string) (string, error) {
	// Try exact match first if we know the version
	if c.agentJarPath != "" {
		if _, err := os.Stat(c.agentJarPath); err == nil {
			return c.agentJarPath, nil
		}
	}

	// Search for contrast-security-*.jar
	matches, _ := filepath.Glob(filepath.Join(frameworkDir, "contrast-security-*.jar"))
	if len(matches) > 0 {
		return matches[0], nil
	}

	// Search for any contrast*.jar
	matches, _ = filepath.Glob(filepath.Join(frameworkDir, "contrast*.jar"))
	if len(matches) > 0 {
		return matches[0], nil
	}

	// Walk recursively as fallback
	var foundPath string
	filepath.Walk(frameworkDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if !info.IsDir() && strings.Contains(info.Name(), "contrast") && strings.HasSuffix(info.Name(), ".jar") {
			foundPath = path
			return filepath.SkipAll
		}
		return nil
	})

	if foundPath != "" {
		return foundPath, nil
	}

	return "", fmt.Errorf("contrast security agent JAR not found in %s", frameworkDir)
}

// Supply downloads and installs the Contrast Security agent
func (c *ContrastSecurityAgentFramework) Supply() error {
	c.context.Log.Info("Installing Contrast Security Agent")

	dep, err := c.context.Manifest.DefaultVersion("contrast-security")
	if err != nil {
		return fmt.Errorf("failed to get contrast-security dependency: %w", err)
	}

	frameworkDir := filepath.Join(c.context.Stager.DepDir(), "contrast-security")

	// Use InstallDependency instead of InstallOnlyVersion to properly extract
	if err := c.context.Installer.InstallDependency(dep, frameworkDir); err != nil {
		return fmt.Errorf("failed to install contrast-security agent: %w", err)
	}

	// Find the actual JAR file that was installed
	agentJar, err := c.findContrastAgent(frameworkDir)
	if err != nil {
		return fmt.Errorf("failed to locate contrast-security agent after installation: %w", err)
	}
	c.agentJarPath = agentJar
	c.context.Log.Debug("Installed Contrast Security agent at: %s", agentJar)

	// Store credentials for use in Finalize
	vcapServices, err := GetVCAPServices()
	if err != nil {
		return fmt.Errorf("failed to parse VCAP_SERVICES: %w", err)
	}

	service := c.findContrastService(vcapServices)
	if service != nil {
		c.credentials = service.Credentials
	}

	c.context.Log.Info("Contrast Security Agent installed successfully")
	return nil
}

// Finalize configures the Contrast Security agent for runtime
func (c *ContrastSecurityAgentFramework) Finalize() error {
	c.context.Log.Info("Configuring Contrast Security Agent")

	// Find the Contrast Security agent JAR dynamically
	frameworkDir := filepath.Join(c.context.Stager.DepDir(), "contrast-security")
	agentJarPath, err := c.findContrastAgent(frameworkDir)
	if err != nil {
		return fmt.Errorf("failed to locate contrast security agent JAR: %w", err)
	}
	c.agentJarPath = agentJarPath
	c.context.Log.Debug("Found Contrast Security agent at: %s", agentJarPath)

	// Get credentials if not already set
	if c.credentials == nil {
		vcapServices, err := GetVCAPServices()
		if err != nil {
			c.context.Log.Warning("Failed to parse VCAP_SERVICES: %s", err)
			return nil
		}

		service := c.findContrastService(vcapServices)
		if service != nil {
			c.credentials = service.Credentials
		}
	}

	// Write configuration file
	if c.credentials != nil {
		configPath := filepath.Join(filepath.Dir(c.agentJarPath), "contrast.config")
		c.configPath = configPath
		if err := c.writeConfiguration(configPath); err != nil {
			c.context.Log.Warning("Failed to write Contrast Security configuration: %s", err)
			return nil
		}
	}

	// Convert staging paths to runtime paths using $DEPS_DIR
	agentRelPath, err := filepath.Rel(c.context.Stager.DepDir(), c.agentJarPath)
	if err != nil {
		return fmt.Errorf("failed to compute relative path for agent jar: %w", err)
	}
	runtimeAgentPath := filepath.Join("$DEPS_DIR/0", agentRelPath)

	configRelPath, err := filepath.Rel(c.context.Stager.DepDir(), c.configPath)
	if err != nil {
		return fmt.Errorf("failed to compute relative path for config: %w", err)
	}
	runtimeConfigPath := filepath.Join("$DEPS_DIR/0", configRelPath)

	// Build JAVA_OPTS with javaagent and system properties using runtime paths
	javaOpts := fmt.Sprintf("-javaagent:%s=%s -Dcontrast.dir=$TMPDIR", runtimeAgentPath, runtimeConfigPath)

	// Write JAVA_OPTS to .opts file with priority 18 (Ruby buildpack line 52)
	if err := writeJavaOptsFile(c.context, 18, "contrast_security", javaOpts); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	c.context.Log.Info("Contrast Security Agent configured successfully (priority 18)")
	return nil
}

// findContrastService locates the Contrast Security service in VCAP_SERVICES
func (c *ContrastSecurityAgentFramework) findContrastService(vcapServices VCAPServices) *VCAPService {
	// Try standard service label
	service := vcapServices.GetService("contrast-security")
	if service != nil {
		return service
	}

	// Try user-provided services with pattern matching
	if services, ok := vcapServices["user-provided"]; ok {
		for _, svc := range services {
			if containsIgnoreCase(svc.Name, "contrast-security") || containsIgnoreCase(svc.Name, "contrast") {
				return &svc
			}
		}
	}

	// Check all services for tags
	for _, serviceList := range vcapServices {
		for _, svc := range serviceList {
			for _, tag := range svc.Tags {
				if containsIgnoreCase(tag, "contrast-security") || containsIgnoreCase(tag, "contrast") {
					return &svc
				}
			}
		}
	}

	return nil
}

// writeConfiguration writes the Contrast Security XML configuration file
func (c *ContrastSecurityAgentFramework) writeConfiguration(configPath string) error {
	apiKey := c.getCredential("api_key")
	serviceKey := c.getCredential("service_key")
	teamserverURL := c.getCredential("teamserver_url")
	username := c.getCredential("username")

	if apiKey == "" || serviceKey == "" || teamserverURL == "" || username == "" {
		return fmt.Errorf("missing required Contrast Security credentials")
	}

	xml := fmt.Sprintf(`<?xml version="1.0" encoding="UTF-8"?>
<contrast>
  <id>default</id>
  <global-key>%s</global-key>
  <url>%s/Contrast/s/</url>
  <results-mode>never</results-mode>
  <user>
    <id>%s</id>
    <key>%s</key>
  </user>
  <plugins>
    <plugin>com.aspectsecurity.contrast.runtime.agent.plugins.security.SecurityPlugin</plugin>
    <plugin>com.aspectsecurity.contrast.runtime.agent.plugins.architecture.ArchitecturePlugin</plugin>
    <plugin>com.aspectsecurity.contrast.runtime.agent.plugins.appupdater.ApplicationUpdatePlugin</plugin>
    <plugin>com.aspectsecurity.contrast.runtime.agent.plugins.sitemap.SitemapPlugin</plugin>
    <plugin>com.aspectsecurity.contrast.runtime.agent.plugins.frameworks.FrameworkSupportPlugin</plugin>
    <plugin>com.aspectsecurity.contrast.runtime.agent.plugins.http.HttpPlugin</plugin>
  </plugins>
</contrast>
`, apiKey, teamserverURL, username, serviceKey)

	return os.WriteFile(configPath, []byte(xml), 0644)
}

// getCredential retrieves a credential value from the stored credentials
func (c *ContrastSecurityAgentFramework) getCredential(key string) string {
	if c.credentials == nil {
		return ""
	}
	if val, ok := c.credentials[key].(string); ok {
		return val
	}
	return ""
}
