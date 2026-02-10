package frameworks

import (
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"go.yaml.in/yaml/v3"
	"os"
	"strconv"
	"strings"
)

// DebugFramework implements Java remote debugging support
// Enables JDWP (Java Debug Wire Protocol) for remote debugging
type DebugFramework struct {
	context *common.Context
}

// NewDebugFramework creates a new Debug framework instance
func NewDebugFramework(ctx *common.Context) *DebugFramework {
	return &DebugFramework{context: ctx}
}

// Detect checks if debugging should be enabled
func (d *DebugFramework) Detect() (string, error) {
	// Check if debug is enabled in configuration
	config, err := d.loadConfig()
	if err != nil {
		d.context.Log.Warning("Failed to load debug config: %s", err.Error())
		return "", nil // Don't fail the build
	}
	if !config.isEnabled() {
		return "", nil
	}

	port := config.getPort()
	return fmt.Sprintf("debug=%d", port), nil
}

// Supply performs debug setup during supply phase
func (d *DebugFramework) Supply() error {
	config, err := d.loadConfig()
	if err != nil {
		d.context.Log.Warning("Failed to load debug config: %s", err.Error())
		return nil // Don't fail the build
	}
	if !config.isEnabled() {
		return nil
	}

	port := config.getPort()
	suspend := config.getSuspend()

	suspendMsg := ""
	if suspend {
		suspendMsg = ", suspended on start"
	}

	d.context.Log.BeginStep("Debugging enabled on port %d%s", port, suspendMsg)
	return nil
}

// Finalize adds debug options to JAVA_OPTS
func (d *DebugFramework) Finalize() error {
	config, err := d.loadConfig()
	if err != nil {
		d.context.Log.Warning("Failed to load debug config: %s", err.Error())
		return nil // Don't fail the build
	}
	if !config.isEnabled() {
		return nil
	}

	port := config.getPort()
	suspend := config.getSuspend()

	// Build JDWP agent string
	suspendValue := "n"
	if suspend {
		suspendValue = "y"
	}

	debugOpts := fmt.Sprintf("-agentlib:jdwp=transport=dt_socket,server=y,address=%d,suspend=%s", port, suspendValue)

	// Write JAVA_OPTS to .opts file with priority 20 (Ruby buildpack line 54)
	if err := writeJavaOptsFile(d.context, 20, "debug", debugOpts); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	return nil
}

// isEnabled checks if debugging is enabled
func (d *debugConfig) isEnabled() bool {
	// Check BPL_DEBUG_ENABLED first (Cloud Native Buildpacks convention)
	bplEnabled := os.Getenv("BPL_DEBUG_ENABLED")
	if bplEnabled == "true" || bplEnabled == "1" {
		return true
	}
	if bplEnabled == "false" || bplEnabled == "0" {
		return false
	}

	return d.Enabled
}

// getPort returns the debug port
func (d *debugConfig) getPort() int {
	// Check BPL_DEBUG_PORT first (Cloud Native Buildpacks convention)
	bplPort := os.Getenv("BPL_DEBUG_PORT")
	if bplPort != "" {
		if port, err := strconv.Atoi(bplPort); err == nil && port > 0 {
			return port
		}
	}

	return d.Port
}

// getSuspend returns whether to suspend on start
func (d *debugConfig) getSuspend() bool {
	return d.Suspend
}

type debugConfig struct {
	Enabled bool `yaml:"enabled"`
	Port    int  `yaml:"port"`
	Suspend bool `yaml:"suspend"`
}

func (d *DebugFramework) loadConfig() (*debugConfig, error) {
	// initialize default values
	dbgConfig := &debugConfig{
		Enabled: false,
		Port:    8000,
		Suspend: false,
	}
	config := os.Getenv("JBP_CONFIG_DEBUG")
	err := validateFields(config, dbgConfig)
	if err != nil {
		d.context.Log.Warning("Unknown user config values: %w", err)
	}
	if config != "" {
		yamlHandler := common.YamlHandler{}
		// overlay JBP_CONFIG_DEBUG over default values
		if err := yamlHandler.Unmarshal([]byte(config), &dbgConfig); err != nil {
			return nil, fmt.Errorf("failed to parse JBP_CONFIG_DEBUG: %w", err)
		}
	}
	return dbgConfig, nil
}

func validateFields(data string, cfg *debugConfig) error {
	dec := yaml.NewDecoder(strings.NewReader(data))
	dec.KnownFields(true)

	if err := dec.Decode(&cfg); err != nil {
		return err
	}

	return nil
}

// Helper function to check if string contains substring
func contains(s, substr string) bool {
	return findInString(s, substr) != -1
}

// Helper function to find substring in string
func findInString(s, substr string) int {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return i
		}
	}
	return -1
}

// Helper function to extract number from string
func extractNumber(s string) string {
	num := ""
	for i := 0; i < len(s); i++ {
		if s[i] >= '0' && s[i] <= '9' {
			num += string(s[i])
		} else if num != "" {
			break
		}
	}
	return num
}
