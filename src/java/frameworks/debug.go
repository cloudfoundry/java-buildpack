package frameworks

import (
	"fmt"
	"os"
	"strconv"
)

// DebugFramework implements Java remote debugging support
// Enables JDWP (Java Debug Wire Protocol) for remote debugging
type DebugFramework struct {
	context *Context
}

// NewDebugFramework creates a new Debug framework instance
func NewDebugFramework(ctx *Context) *DebugFramework {
	return &DebugFramework{context: ctx}
}

// Detect checks if debugging should be enabled
func (d *DebugFramework) Detect() (string, error) {
	// Check if debug is enabled in configuration
	enabled := d.isEnabled()
	if !enabled {
		return "", nil
	}

	port := d.getPort()
	return fmt.Sprintf("debug=%d", port), nil
}

// Supply performs debug setup during supply phase
func (d *DebugFramework) Supply() error {
	if !d.isEnabled() {
		return nil
	}

	port := d.getPort()
	suspend := d.getSuspend()

	suspendMsg := ""
	if suspend {
		suspendMsg = ", suspended on start"
	}

	d.context.Log.BeginStep("Debugging enabled on port %d%s", port, suspendMsg)
	return nil
}

// Finalize adds debug options to JAVA_OPTS
func (d *DebugFramework) Finalize() error {
	if !d.isEnabled() {
		return nil
	}

	port := d.getPort()
	suspend := d.getSuspend()

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
func (d *DebugFramework) isEnabled() bool {
	// Check BPL_DEBUG_ENABLED first (Cloud Native Buildpacks convention)
	bplEnabled := os.Getenv("BPL_DEBUG_ENABLED")
	if bplEnabled == "true" || bplEnabled == "1" {
		return true
	}
	if bplEnabled == "false" || bplEnabled == "0" {
		return false
	}

	// Check JBP_CONFIG_DEBUG environment variable (Java Buildpack convention)
	config := os.Getenv("JBP_CONFIG_DEBUG")

	// Parse the config to check for enabled: true
	// For simplicity, if JBP_CONFIG_DEBUG is set and contains "enabled", check its value
	// A more robust implementation would parse YAML
	if config != "" {
		// Simple check: if it contains "enabled: true" or just "true"
		if contains(config, "enabled: true") || contains(config, "'enabled': true") {
			return true
		}
		if contains(config, "enabled: false") || contains(config, "'enabled': false") {
			return false
		}
	}

	// Default to disabled (as per config/debug.yml)
	return false
}

// getPort returns the debug port
func (d *DebugFramework) getPort() int {
	// Check BPL_DEBUG_PORT first (Cloud Native Buildpacks convention)
	bplPort := os.Getenv("BPL_DEBUG_PORT")
	if bplPort != "" {
		if port, err := strconv.Atoi(bplPort); err == nil && port > 0 {
			return port
		}
	}

	// Check JBP_CONFIG_DEBUG for port setting (Java Buildpack convention)
	config := os.Getenv("JBP_CONFIG_DEBUG")
	if config != "" {
		// Simple parsing - look for port: XXXX
		// A more robust implementation would parse YAML
		if idx := findInString(config, "port:"); idx != -1 {
			portStr := extractNumber(config[idx:])
			if port, err := strconv.Atoi(portStr); err == nil && port > 0 {
				return port
			}
		}
	}

	// Default port
	return 8000
}

// getSuspend returns whether to suspend on start
func (d *DebugFramework) getSuspend() bool {
	// Check JBP_CONFIG_DEBUG for suspend setting
	config := os.Getenv("JBP_CONFIG_DEBUG")
	if config != "" {
		if contains(config, "suspend: true") || contains(config, "'suspend': true") {
			return true
		}
	}

	// Default to false
	return false
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
