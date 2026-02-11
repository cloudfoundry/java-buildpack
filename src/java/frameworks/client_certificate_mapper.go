package frameworks

import (
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
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
	config, err := c.loadConfig()
	if err != nil {
		c.context.Log.Warning("Failed to load ccm config: %s", err.Error())
		return "", nil // Don't fail the build
	}

	if !config.isEnabled() {
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

func (c *ClientCertificateMapperFramework) loadConfig() (*ccmConfig, error) {
	// initialize default values
	mapperConfig := ccmConfig{
		Enabled: true,
	}
	config := os.Getenv("JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER")
	yamlHandler := common.YamlHandler{}
	err := yamlHandler.ValidateFields([]byte(config), &mapperConfig)
	if err != nil {
		c.context.Log.Warning("Unknown user config values: %s", err.Error())
	}
	if config != "" {
		// overlay JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER over default values
		if err := yamlHandler.Unmarshal([]byte(config), &mapperConfig); err != nil {
			return nil, fmt.Errorf("failed to parse JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER: %w", err)
		}
	}
	return &mapperConfig, nil
}

type ccmConfig struct {
	Enabled bool `yaml:"enabled"`
}

// isEnabled checks if client certificate mapper is enabled
func (c *ccmConfig) isEnabled() bool {
	return c.Enabled
}
