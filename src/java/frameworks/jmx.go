package frameworks

import (
	"fmt"
	"os"
	"strconv"
)

// JmxFramework implements JMX (Java Management Extensions) support
// Enables remote JMX monitoring and management
type JmxFramework struct {
	context *Context
}

// NewJmxFramework creates a new JMX framework instance
func NewJmxFramework(ctx *Context) *JmxFramework {
	return &JmxFramework{context: ctx}
}

// Detect checks if JMX should be enabled
func (j *JmxFramework) Detect() (string, error) {
	// Check if JMX is enabled in configuration
	enabled := j.isEnabled()
	if !enabled {
		return "", nil
	}

	port := j.getPort()
	return fmt.Sprintf("jmx=%d", port), nil
}

// Supply performs JMX setup during supply phase
func (j *JmxFramework) Supply() error {
	if !j.isEnabled() {
		return nil
	}

	port := j.getPort()
	j.context.Log.BeginStep("JMX enabled on port %d", port)
	return nil
}

// Finalize adds JMX options to JAVA_OPTS
func (j *JmxFramework) Finalize() error {
	if !j.isEnabled() {
		return nil
	}

	port := j.getPort()

	// Build JMX system properties
	jmxOpts := fmt.Sprintf(
		"-Djava.rmi.server.hostname=127.0.0.1 "+
			"-Dcom.sun.management.jmxremote.authenticate=false "+
			"-Dcom.sun.management.jmxremote.ssl=false "+
			"-Dcom.sun.management.jmxremote.port=%d "+
			"-Dcom.sun.management.jmxremote.rmi.port=%d",
		port, port,
	)

	// Append to JAVA_OPTS (preserves values from other frameworks)
	if err := AppendToJavaOpts(j.context, jmxOpts); err != nil {
		return fmt.Errorf("failed to set JAVA_OPTS for JMX: %w", err)
	}

	return nil
}

// isEnabled checks if JMX is enabled
func (j *JmxFramework) isEnabled() bool {
	// Check BPL_JMX_ENABLED first (Cloud Native Buildpacks convention)
	bplEnabled := os.Getenv("BPL_JMX_ENABLED")
	if bplEnabled == "true" || bplEnabled == "1" {
		return true
	}
	if bplEnabled == "false" || bplEnabled == "0" {
		return false
	}

	// Check JBP_CONFIG_JMX environment variable (Java Buildpack convention)
	config := os.Getenv("JBP_CONFIG_JMX")

	// Parse the config to check for enabled: true
	if config != "" {
		if contains(config, "enabled: true") || contains(config, "'enabled': true") {
			return true
		}
		if contains(config, "enabled: false") || contains(config, "'enabled': false") {
			return false
		}
	}

	// Default to disabled (as per config/jmx.yml)
	return false
}

// getPort returns the JMX port
func (j *JmxFramework) getPort() int {
	// Check BPL_JMX_PORT first (Cloud Native Buildpacks convention)
	bplPort := os.Getenv("BPL_JMX_PORT")
	if bplPort != "" {
		if port, err := strconv.Atoi(bplPort); err == nil && port > 0 {
			return port
		}
	}

	// Check JBP_CONFIG_JMX for port setting (Java Buildpack convention)
	config := os.Getenv("JBP_CONFIG_JMX")
	if config != "" {
		// Simple parsing - look for port: XXXX
		if idx := findInString(config, "port:"); idx != -1 {
			portStr := extractNumber(config[idx:])
			if port, err := strconv.Atoi(portStr); err == nil && port > 0 {
				return port
			}
		}
	}

	// Default port
	return 5000
}
