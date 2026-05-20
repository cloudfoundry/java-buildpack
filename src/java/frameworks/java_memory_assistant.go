package frameworks

import (
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"os"
	"path/filepath"
	"strings"
)

// JavaMemoryAssistantFramework implements Java Memory Assistant agent support
// This framework provides automatic heap dump generation based on memory usage thresholds
type JavaMemoryAssistantFramework struct {
	context *common.Context
}

// NewJavaMemoryAssistantFramework creates a new Java Memory Assistant framework instance
func NewJavaMemoryAssistantFramework(ctx *common.Context) *JavaMemoryAssistantFramework {
	return &JavaMemoryAssistantFramework{context: ctx}
}

// Detect checks if Java Memory Assistant should be included
// Must be explicitly enabled via configuration (disabled by default)
func (j *JavaMemoryAssistantFramework) Detect() (string, error) {
	// Check if explicitly enabled via configuration
	config, err := j.loadConfig()
	if err != nil {
		j.context.Log.Warning("Failed to load java memory assistant config: %s", err.Error())
		return "", nil // Don't fail the build
	}
	if !config.isEnabled() {
		j.context.Log.Debug("Java Memory Assistant is disabled (default)")
		return "", nil
	}

	j.context.Log.Debug("Java Memory Assistant is enabled")
	return "Java Memory Assistant", nil
}

// Supply installs the Java Memory Assistant agent and cleanup utility
func (j *JavaMemoryAssistantFramework) Supply() error {
	j.context.Log.Debug("Installing Java Memory Assistant")

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

	j.context.Log.Debug("Installed Java Memory Assistant version %s", agentDep.Version)

	// Get cleanup utility dependency (optional)
	cleanupDep, err := j.context.Manifest.DefaultVersion("java-memory-assistant-cleanup")
	if err == nil {
		cleanupDir := filepath.Join(j.context.Stager.DepDir(), "java_memory_assistant_cleanup")
		if err := j.context.Installer.InstallDependency(cleanupDep, cleanupDir); err != nil {
			j.context.Log.Warning("Failed to install Java Memory Assistant cleanup utility: %s", err.Error())
		} else {
			j.context.Log.Debug("Installed Java Memory Assistant cleanup utility version %s", cleanupDep.Version)
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

	// Get buildpack index for multi-buildpack support
	depsIdx := j.context.Stager.DepsIdx()

	// Convert staging path to runtime path
	// Runtime: $DEPS_DIR/<idx>/java_memory_assistant/java-memory-assistant-x.x.x.jar
	relPath := filepath.Base(matches[0])
	runtimeAgentPath := fmt.Sprintf("$DEPS_DIR/%s/java_memory_assistant/%s", depsIdx, relPath)

	// Build agent configuration
	agentConfig := j.buildAgentConfig()

	// Construct javaagent argument
	javaagentArg := fmt.Sprintf("-javaagent:%s %s", runtimeAgentPath, agentConfig)

	// For Java 9+, add --add-opens to allow access to internal management APIs
	// This is required for Java Memory Assistant to access com.sun.management.HotSpotDiagnosticMXBean
	// See: https://github.com/SAP/java-memory-assistant#running-the-java-memory-assistant-on-java-11
	javaVersion, err := common.GetJavaMajorVersion()
	if err == nil && javaVersion >= 9 {
		addOpensFlag := "--add-opens jdk.management/com.sun.management.internal=ALL-UNNAMED"
		javaagentArg = javaagentArg + " " + addOpensFlag
		j.context.Log.Info("Added --add-opens flag for Java %d to allow JMA access to internal management APIs", javaVersion)
	} else if err != nil {
		j.context.Log.Warning("Could not determine Java version: %s (skipping --add-opens)", err.Error())
	}

	// Write to .opts file using priority 28
	if err := writeJavaOptsFile(j.context, 28, "java_memory_assistant", javaagentArg); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	j.context.Log.Debug("Java Memory Assistant configured (priority 28)")
	return nil
}

// buildAgentConfig constructs the agent configuration string from environment variables
func (j *JavaMemoryAssistantFramework) buildAgentConfig() string {
	var configParts []string

	// Get configuration from JBP_CONFIG_JAVA_MEMORY_ASSISTANT environment variable
	config, err := j.loadConfig()
	if err != nil {
		j.context.Log.Warning("Failed to load java memory assistant config: %s", err.Error())
		return "" // Don't fail the build
	}

	// Heap dump folder: config value takes priority, then volume service, then $PWD
	heapDumpFolder := j.getHeapDumpFolder(config.Agent.HeapDumpFolder)
	if heapDumpFolder != "" {
		configParts = append(configParts, fmt.Sprintf("-Djma.heap_dump_folder=%s", heapDumpFolder))
	}

	// Check interval (default: 5s)
	checkInterval := config.Agent.CheckInterval
	configParts = append(configParts, fmt.Sprintf("-Djma.check_interval=%s", checkInterval))

	// Max frequency (default: 1/1m)
	maxFrequency := config.Agent.MaxFrequency
	configParts = append(configParts, fmt.Sprintf("-Djma.max_frequency=%s", maxFrequency))

	// Log level (only if set)
	if logLevel := config.Agent.LogLevel; logLevel != "" {
		configParts = append(configParts, fmt.Sprintf("-Djma.log_level=%s", logLevel))
	}

	// Thresholds (default: old_gen >600MB)
	thresholds := config.getThresholds()
	for memArea, threshold := range thresholds {
		if threshold != "" {
			configParts = append(configParts, fmt.Sprintf("-Djma.thresholds.%s=%s", memArea, threshold))
		}
	}

	return strings.Join(configParts, " ")
}

// getHeapDumpFolder determines the heap dump folder location.
// Priority: explicit config value > volume service mount > $PWD default.
func (j *JavaMemoryAssistantFramework) getHeapDumpFolder(configuredFolder string) string {
	if configuredFolder != "" {
		return configuredFolder
	}

	// Check for volume service mounts
	vcapServices := os.Getenv("VCAP_SERVICES")
	if vcapServices != "" && contains(vcapServices, "heap-dump") {
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

func (j *JavaMemoryAssistantFramework) loadConfig() (*javaMemoryAssistantConfig, error) {
	// initialize default values
	jConfig := javaMemoryAssistantConfig{
		Enabled: false,
		Agent: Agent{
			HeapDumpFolder: "",
			CheckInterval:  "5s",
			MaxFrequency:   "1/1m",
			LogLevel:       "",
			Thresholds: Thresholds{
				Heap:                     "",
				CodeCache:                "",
				Metaspace:                "",
				PermGen:                  "",
				CompressedClass:          "",
				Eden:                     "",
				Survivor:                 "",
				OldGen:                   ">600MB",
				TenuredGen:               "",
				CodeHeapNonNMethods:      "",
				CodeHeapNonProfiled:      "",
				CodeHeapProfiledNMethods: "",
			},
		},
		CleanUp: CleanUp{
			MaxDumpCount: 1,
		},
	}
	config := os.Getenv("JBP_CONFIG_JAVA_MEMORY_ASSISTANT")
	if config != "" {
		yamlHandler := common.YamlHandler{}
		err := yamlHandler.ValidateFields([]byte(config), &jConfig)
		if err != nil {
			j.context.Log.Warning("Unknown user config values: %s", err.Error())
		}
		// overlay JBP_CONFIG_JAVA_MEMORY_ASSISTANT over default values
		if err = yamlHandler.Unmarshal([]byte(config), &jConfig); err != nil {
			return nil, fmt.Errorf("failed to parse JBP_CONFIG_JAVA_MEMORY_ASSISTANT: %w", err)
		}
	}
	return &jConfig, nil
}

// getThresholds extracts memory threshold configuration
func (j *javaMemoryAssistantConfig) getThresholds() map[string]string {
	yamlHandler := common.YamlHandler{}
	data, _ := yamlHandler.Marshal(j.Agent.Thresholds)

	var result map[string]string
	yamlHandler.Unmarshal(data, &result)

	return result
}

// isEnabled checks if Java Memory Assistant is enabled
// Default is false (disabled) unless explicitly enabled via configuration
func (j *javaMemoryAssistantConfig) isEnabled() bool {
	return j.Enabled
}

type javaMemoryAssistantConfig struct {
	Enabled bool    `yaml:"enabled"`
	Agent   Agent   `yaml:"agent"`
	CleanUp CleanUp `yaml:"clean_up"`
}

type Agent struct {
	HeapDumpFolder string     `yaml:"heap_dump_folder"`
	CheckInterval  string     `yaml:"check_interval"`
	MaxFrequency   string     `yaml:"max_frequency"`
	LogLevel       string     `yaml:"log_level"`
	Thresholds     Thresholds `yaml:"thresholds"`
}

type Thresholds struct {
	Heap                     string `yaml:"heap"`
	CodeCache                string `yaml:"code_cache"`
	Metaspace                string `yaml:"metaspace"`
	PermGen                  string `yaml:"perm_gen"`
	CompressedClass          string `yaml:"compressed_class"`
	Eden                     string `yaml:"eden"`
	Survivor                 string `yaml:"survivor"`
	OldGen                   string `yaml:"old_gen"`
	TenuredGen               string `yaml:"tenured_gen"`
	CodeHeapNonNMethods      string `yaml:"code_heap.non_nmethods"`
	CodeHeapNonProfiled      string `yaml:"code_heap.non_profiled_nmethods"`
	CodeHeapProfiledNMethods string `yaml:"code_heap.profiled_nmethods"`
}

type CleanUp struct {
	MaxDumpCount int `yaml:"max_dump_count"`
}

func (j *JavaMemoryAssistantFramework) DependencyIdentifier() string {
	return "java-memory-assistant"
}
