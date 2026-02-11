package frameworks

import (
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"os"
	"strconv"
)

// JmxFramework implements JMX (Java Management Extensions) support
// Enables remote JMX monitoring and management
type JmxFramework struct {
	context *common.Context
}

// NewJmxFramework creates a new JMX framework instance
func NewJmxFramework(ctx *common.Context) *JmxFramework {
	return &JmxFramework{context: ctx}
}

// Detect checks if JMX should be enabled
func (j *JmxFramework) Detect() (string, error) {
	// Check if JMX is enabled in configuration
	config, err := j.loadConfig()
	if err != nil {
		j.context.Log.Warning("Failed to load debug config: %s", err.Error())
		return "", nil // Don't fail the build
	}
	if !config.isEnabled() {
		return "", nil
	}

	port := config.getPort()
	return fmt.Sprintf("jmx=%d", port), nil
}

// Supply performs JMX setup during supply phase
func (j *JmxFramework) Supply() error {
	config, err := j.loadConfig()
	if err != nil {
		j.context.Log.Warning("Failed to load debug config: %s", err.Error())
		return nil // Don't fail the build
	}

	port := config.getPort()
	j.context.Log.BeginStep("JMX enabled on port %d", port)
	return nil
}

// Finalize adds JMX options to JAVA_OPTS via profile.d script
func (j *JmxFramework) Finalize() error {
	config, err := j.loadConfig()
	if err != nil {
		j.context.Log.Warning("Failed to load debug config: %s", err.Error())
		return nil // Don't fail the build
	}

	port := config.getPort()

	// Build JMX system properties
	jmxOpts := fmt.Sprintf(
		"-Djava.rmi.server.hostname=127.0.0.1 "+
			"-Dcom.sun.management.jmxremote.authenticate=false "+
			"-Dcom.sun.management.jmxremote.ssl=false "+
			"-Dcom.sun.management.jmxremote.port=%d "+
			"-Dcom.sun.management.jmxremote.rmi.port=%d",
		port, port,
	)

	// Write JAVA_OPTS to .opts file with priority 29 (Ruby buildpack line 63)
	if err := writeJavaOptsFile(j.context, 29, "jmx", jmxOpts); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	return nil
}

func (j *JmxFramework) loadConfig() (*jmxConfig, error) {
	// initialize default values
	jConfig := jmxConfig{
		Enabled: false,
		Port:    5000,
	}
	config := os.Getenv("JBP_CONFIG_JMX")
	if config != "" {
		yamlHandler := common.YamlHandler{}
		err := yamlHandler.ValidateFields([]byte(config), &jConfig)
		if err != nil {
			j.context.Log.Warning("Unknown user config values: %s", err.Error())
		}
		// overlay JBP_CONFIG_JMX over default values
		if err = yamlHandler.Unmarshal([]byte(config), &jConfig); err != nil {
			return nil, fmt.Errorf("failed to parse JBP_CONFIG_JMX: %w", err)
		}
	}
	return &jConfig, nil
}

// isEnabled checks if JMX is enabled
func (j *jmxConfig) isEnabled() bool {
	// Check BPL_JMX_ENABLED first (Cloud Native Buildpacks convention)
	bplEnabled := os.Getenv("BPL_JMX_ENABLED")
	if bplEnabled == "true" || bplEnabled == "1" {
		return true
	}
	if bplEnabled == "false" || bplEnabled == "0" {
		return false
	}

	// Check JBP_CONFIG_JMX environment variable (Java Buildpack convention)
	return j.Enabled
}

// getPort returns the JMX port
func (j *jmxConfig) getPort() int {
	// Check BPL_JMX_PORT first (Cloud Native Buildpacks convention)
	bplPort := os.Getenv("BPL_JMX_PORT")
	if bplPort != "" {
		if port, err := strconv.Atoi(bplPort); err == nil && port > 0 {
			return port
		}
	}

	return j.Port
}

type jmxConfig struct {
	Enabled bool `yaml:"enabled"`
	Port    int  `yaml:"port"`
}
