package frameworks

import (
	"fmt"
	"os"
	"path/filepath"
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

// Supply downloads and installs the Contrast Security agent
func (c *ContrastSecurityAgentFramework) Supply() error {
	c.context.Log.Info("Installing Contrast Security Agent")

	dep, err := c.context.Manifest.DefaultVersion("contrast-security")
	if err != nil {
		return fmt.Errorf("failed to get contrast-security dependency: %w", err)
	}

	frameworkDir := filepath.Join(c.context.Stager.DepDir(), "contrast-security")
	if err := os.MkdirAll(frameworkDir, 0755); err != nil {
		return fmt.Errorf("failed to create contrast-security directory: %w", err)
	}

	c.agentJarPath = filepath.Join(frameworkDir, fmt.Sprintf("contrast-security-%s.jar", dep.Version))
	if err := c.context.Installer.InstallOnlyVersion(dep.Name, c.agentJarPath); err != nil {
		return fmt.Errorf("failed to install contrast-security agent: %w", err)
	}

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

	// Reconstruct paths if not set (separate finalize instance)
	if c.agentJarPath == "" {
		frameworkDir := filepath.Join(c.context.Stager.DepDir(), "contrast-security")
		dep, err := c.context.Manifest.DefaultVersion("contrast-security")
		if err != nil {
			c.context.Log.Warning("Failed to get contrast-security version: %s", err)
			return nil
		}
		c.agentJarPath = filepath.Join(frameworkDir, fmt.Sprintf("contrast-security-%s.jar", dep.Version))
		c.configPath = filepath.Join(frameworkDir, "contrast.config")
	}

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

	// Append javaagent to JAVA_OPTS (preserves values from other frameworks)
	javaOpts := fmt.Sprintf("-javaagent:%s=%s", c.agentJarPath, c.configPath)
	if err := AppendToJavaOpts(c.context, javaOpts); err != nil {
		c.context.Log.Warning("Failed to set JAVA_OPTS for Contrast Security: %s", err)
		return nil
	}

	// Append system properties
	contrastDir := fmt.Sprintf("-Dcontrast.dir=$TMPDIR")
	if err := AppendToJavaOpts(c.context, contrastDir); err != nil {
		c.context.Log.Warning("Failed to set contrast.dir: %s", err)
		return nil
	}

	c.context.Log.Info("Contrast Security Agent configured successfully")
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
