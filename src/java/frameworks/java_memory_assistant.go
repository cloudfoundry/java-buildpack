package frameworks

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// JavaMemoryAssistantFramework implements Java Memory Assistant agent support
// This framework provides automatic heap dump generation based on memory usage thresholds
type JavaMemoryAssistantFramework struct {
	context *Context
}

// NewJavaMemoryAssistantFramework creates a new Java Memory Assistant framework instance
func NewJavaMemoryAssistantFramework(ctx *Context) *JavaMemoryAssistantFramework {
	return &JavaMemoryAssistantFramework{context: ctx}
}

// Detect checks if Java Memory Assistant should be included
// Must be explicitly enabled via configuration (disabled by default)
func (j *JavaMemoryAssistantFramework) Detect() (string, error) {
	// Check if explicitly enabled via configuration
	if !j.isEnabled() {
		j.context.Log.Debug("Java Memory Assistant is disabled (default)")
		return "", nil
	}

	j.context.Log.Debug("Java Memory Assistant is enabled")
	return "Java Memory Assistant", nil
}

// Supply installs the Java Memory Assistant agent and cleanup utility
func (j *JavaMemoryAssistantFramework) Supply() error {
	j.context.Log.BeginStep("Installing Java Memory Assistant")

	// Get java-memory-assistant agent dependency from manifest
	agentDep, err := j.context.Manifest.DefaultVersion("java-memory-assistant")
	if err != nil {
		return fmt.Errorf("unable to determine Java Memory Assistant version: %w", err)
	}

	// Install Java Memory Assistant agent JAR
	agentDir := filepath.Join(j.context.Stager.DepDir(), "java_memory_assistant")
	if err := j.context.Installer.InstallDependency(agentDep, agentDir); err != nil {
		return fmt.Errorf("failed to install Java Memory Assistant: %w", err)
	}

	j.context.Log.Info("Installed Java Memory Assistant version %s", agentDep.Version)

	// Get cleanup utility dependency (optional)
	cleanupDep, err := j.context.Manifest.DefaultVersion("java-memory-assistant-cleanup")
	if err == nil {
		cleanupDir := filepath.Join(j.context.Stager.DepDir(), "java_memory_assistant_cleanup")
		if err := j.context.Installer.InstallDependency(cleanupDep, cleanupDir); err != nil {
			j.context.Log.Warning("Failed to install Java Memory Assistant cleanup utility: %s", err.Error())
		} else {
			j.context.Log.Info("Installed Java Memory Assistant cleanup utility version %s", cleanupDep.Version)
		}
	}

	return nil
}

// Finalize configures the Java Memory Assistant agent as a javaagent
func (j *JavaMemoryAssistantFramework) Finalize() error {
	// Find the installed agent JAR
	agentDir := filepath.Join(j.context.Stager.DepDir(), "java_memory_assistant")
	jarPattern := filepath.Join(agentDir, "java-memory-assistant-*.jar")

	matches, err := filepath.Glob(jarPattern)
	if err != nil || len(matches) == 0 {
		return fmt.Errorf("Java Memory Assistant JAR not found")
	}

	// Convert staging path to runtime path
	// Runtime: $DEPS_DIR/0/java_memory_assistant/java-memory-assistant-x.x.x.jar
	relPath := filepath.Base(matches[0])
	runtimeAgentPath := fmt.Sprintf("$DEPS_DIR/0/java_memory_assistant/%s", relPath)

	// Build agent configuration
	agentConfig := j.buildAgentConfig()

	// Construct javaagent argument
	javaagentArg := fmt.Sprintf("-javaagent:%s=%s", runtimeAgentPath, agentConfig)

	// Write to .opts file using priority 28
	if err := writeJavaOptsFile(j.context, 28, "java_memory_assistant", javaagentArg); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	j.context.Log.Info("Java Memory Assistant configured (priority 28)")
	return nil
}

// buildAgentConfig constructs the agent configuration string from environment variables
func (j *JavaMemoryAssistantFramework) buildAgentConfig() string {
	var configParts []string

	// Get configuration from JBP_CONFIG_JAVA_MEMORY_ASSISTANT environment variable
	config := os.Getenv("JBP_CONFIG_JAVA_MEMORY_ASSISTANT")

	// Parse configuration (simplified - in production, parse YAML properly)
	// For now, we'll use default values that can be overridden

	// Heap dump folder (default: $PWD or volume service mount point)
	heapDumpFolder := j.getHeapDumpFolder()
	if heapDumpFolder != "" {
		configParts = append(configParts, fmt.Sprintf("heap-dump-folder=%s", heapDumpFolder))
	}

	// Check interval (default: 5s)
	checkInterval := j.getConfigValue(config, "check_interval", "5s")
	configParts = append(configParts, fmt.Sprintf("check-interval=%s", checkInterval))

	// Max frequency (default: 1/1m)
	maxFrequency := j.getConfigValue(config, "max_frequency", "1/1m")
	configParts = append(configParts, fmt.Sprintf("max-frequency=%s", maxFrequency))

	// Log level (use buildpack log level if not specified)
	logLevel := j.getConfigValue(config, "log_level", "INFO")
	configParts = append(configParts, fmt.Sprintf("log-level=%s", logLevel))

	// Thresholds (default: old_gen >600MB)
	thresholds := j.getThresholds(config)
	for memArea, threshold := range thresholds {
		configParts = append(configParts, fmt.Sprintf("threshold.%s=%s", memArea, threshold))
	}

	// Max dump count (default: 1)
	maxDumpCount := j.getConfigValue(config, "max_dump_count", "1")
	configParts = append(configParts, fmt.Sprintf("max-dump-count=%s", maxDumpCount))

	return strings.Join(configParts, ",")
}

// getHeapDumpFolder determines the heap dump folder location
// Checks for volume services named "heap-dump" or tagged with "heap-dump"
func (j *JavaMemoryAssistantFramework) getHeapDumpFolder() string {
	// Check for volume service mounts
	// This is a simplified implementation - in production, parse VCAP_SERVICES
	vcapServices := os.Getenv("VCAP_SERVICES")
	if vcapServices != "" && contains(vcapServices, "heap-dump") {
		// If heap-dump volume service exists, use its mount point
		// For now, return a placeholder that would be resolved at runtime
		return "$HEAP_DUMP_VOLUME/heapdumps"
	}

	// Default: use current working directory
	return "$PWD"
}

// getConfigValue extracts a configuration value from the config string
// This is a simplified implementation - in production, parse YAML properly
func (j *JavaMemoryAssistantFramework) getConfigValue(config, key, defaultValue string) string {
	// Simple string matching for now
	// In production, parse YAML and extract values properly
	if config == "" {
		return defaultValue
	}

	// Look for key: value pattern
	searchKey := fmt.Sprintf("%s:", key)
	if contains(config, searchKey) {
		// Extract value (simplified)
		return defaultValue // Return default for now
	}

	return defaultValue
}

// getThresholds extracts memory threshold configuration
func (j *JavaMemoryAssistantFramework) getThresholds(config string) map[string]string {
	thresholds := make(map[string]string)

	// Default threshold: old_gen >600MB
	thresholds["old_gen"] = ">600MB"

	// In production, parse thresholds from config
	// For now, use default
	return thresholds
}

// isEnabled checks if Java Memory Assistant is enabled
// Default is false (disabled) unless explicitly enabled via configuration
func (j *JavaMemoryAssistantFramework) isEnabled() bool {
	// Check JBP_CONFIG_JAVA_MEMORY_ASSISTANT environment variable
	config := os.Getenv("JBP_CONFIG_JAVA_MEMORY_ASSISTANT")

	// Parse the config to check for enabled: true
	if config != "" {
		// Simple check: if it contains "enabled: true" or "'enabled': true"
		if contains(config, "enabled: true") || contains(config, "'enabled': true") ||
			contains(config, "enabled : true") || contains(config, "'enabled' : true") {
			return true
		}
	}

	// Default to disabled
	return false
}
