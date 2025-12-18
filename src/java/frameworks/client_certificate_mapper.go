package frameworks

import (
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"fmt"
	"os"
	"path/filepath"
)

// ClientCertificateMapperFramework implements mTLS client certificate mapper support
// This framework provides automatic mapping of Cloud Foundry client certificates
// for mutual TLS (mTLS) authentication in Java applications
type ClientCertificateMapperFramework struct {
	context *common.Context
}

// NewClientCertificateMapperFramework creates a new client certificate mapper framework instance
func NewClientCertificateMapperFramework(ctx *common.Context) *ClientCertificateMapperFramework {
	return &ClientCertificateMapperFramework{context: ctx}
}

// Detect checks if client certificate mapper should be included
// Enabled by default to support mTLS scenarios, can be disabled via configuration
func (c *ClientCertificateMapperFramework) Detect() (string, error) {
	// Check if explicitly disabled via configuration
	if !c.isEnabled() {
		return "", nil
	}

	// Enabled by default to support mTLS client certificate authentication
	return "Client Certificate Mapper", nil
}

// Supply installs the client certificate mapper JAR
func (c *ClientCertificateMapperFramework) Supply() error {
	c.context.Log.BeginStep("Installing Client Certificate Mapper")

	// Get client-certificate-mapper dependency from manifest
	dep, err := c.context.Manifest.DefaultVersion("client-certificate-mapper")
	if err != nil {
		return fmt.Errorf("unable to determine Client Certificate Mapper version: %w", err)
	}

	// Install client certificate mapper JAR
	mapperDir := filepath.Join(c.context.Stager.DepDir(), "client_certificate_mapper")
	if err := c.context.Installer.InstallDependency(dep, mapperDir); err != nil {
		return fmt.Errorf("failed to install Client Certificate Mapper: %w", err)
	}

	c.context.Log.Info("Installed Client Certificate Mapper version %s", dep.Version)
	return nil
}

// Finalize adds the client certificate mapper JAR to the application classpath
func (c *ClientCertificateMapperFramework) Finalize() error {
	// Find the installed JAR
	mapperDir := filepath.Join(c.context.Stager.DepDir(), "client_certificate_mapper")
	jarPattern := filepath.Join(mapperDir, "client-certificate-mapper-*.jar")

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

	if err := c.context.Stager.WriteEnvFile("CLASSPATH", classpath); err != nil {
		return fmt.Errorf("failed to set CLASSPATH for Client Certificate Mapper: %w", err)
	}

	return nil
}

// isEnabled checks if client certificate mapper is enabled
// Default is true (enabled) to support mTLS scenarios unless explicitly disabled
func (c *ClientCertificateMapperFramework) isEnabled() bool {
	// Check JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER environment variable
	config := os.Getenv("JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER")

	// Parse the config to check for enabled: false
	// For simplicity, if JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER is set and contains "enabled", check its value
	// A more robust implementation would parse YAML
	if config != "" {
		// Simple check: if it contains "enabled: false" or "'enabled': false"
		if contains(config, "enabled: false") || contains(config, "'enabled': false") {
			return false
		}
		if contains(config, "enabled: true") || contains(config, "'enabled': true") {
			return true
		}
	}

	// Default to enabled (to support mTLS client certificate authentication)
	return true
}
