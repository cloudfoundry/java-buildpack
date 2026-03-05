package frameworks

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
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
		c.context.Log.Warning("Failed to load client certificate mapper config: %s", err.Error())
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

	depsIdx := c.context.Stager.DepsIdx()
	runtimePath := fmt.Sprintf("$DEPS_DIR/%s/client_certificate_mapper/%s", depsIdx, filepath.Base(matches[0]))

	profileScript := fmt.Sprintf("export CLASSPATH=\"%s:${CLASSPATH:-}\"\n", runtimePath)
	if err := c.context.Stager.WriteProfileD("client_certificate_mapper.sh", profileScript); err != nil {
		return fmt.Errorf("failed to write client_certificate_mapper.sh profile.d script: %w", err)
	}

	c.context.Log.Debug("Client Certificate Mapper JAR will be added to classpath at runtime: %s", runtimePath)
	return nil
}

func (c *ClientCertificateMapperFramework) loadConfig() (*clientCertificateMapperConfig, error) {
	// initialize default values
	mapperConfig := clientCertificateMapperConfig{
		Enabled: true,
	}
	config := os.Getenv("JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER")
	if config != "" {
		yamlHandler := common.YamlHandler{}
		err := yamlHandler.ValidateFields([]byte(config), &mapperConfig)
		if err != nil {
			c.context.Log.Warning("Unknown user config values: %s", err.Error())
		}
		// overlay JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER over default values
		if err = yamlHandler.Unmarshal([]byte(config), &mapperConfig); err != nil {
			return nil, fmt.Errorf("failed to parse JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER: %w", err)
		}
	}
	return &mapperConfig, nil
}

type clientCertificateMapperConfig struct {
	Enabled bool `yaml:"enabled"`
}

// isEnabled checks if client certificate mapper is enabled
func (c *clientCertificateMapperConfig) isEnabled() bool {
	return c.Enabled
}
