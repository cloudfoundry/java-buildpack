package frameworks

import (
	"fmt"
	"os"
	"strings"

	"gopkg.in/yaml.v2"
)

// JavaOptsFramework implements custom JAVA_OPTS configuration
type JavaOptsFramework struct {
	context *Context
}

// JavaOptsConfig represents the java_opts.yml configuration
type JavaOptsConfig struct {
	FromEnvironment bool     `yaml:"from_environment"`
	JavaOpts        []string `yaml:"java_opts"`
}

// NewJavaOptsFramework creates a new Java Opts framework instance
func NewJavaOptsFramework(ctx *Context) *JavaOptsFramework {
	return &JavaOptsFramework{context: ctx}
}

// Detect always returns true (universal framework for JAVA_OPTS configuration)
func (j *JavaOptsFramework) Detect() (string, error) {
	// Check if there's any configuration to apply
	config, err := j.loadConfig()
	if err != nil {
		j.context.Log.Debug("Failed to load java_opts config: %s", err.Error())
		return "", nil
	}

	// Detect if there are any custom java_opts or if from_environment is enabled
	if len(config.JavaOpts) > 0 || config.FromEnvironment {
		return "Java Opts", nil
	}

	return "", nil
}

// Supply does nothing (no dependencies to install)
func (j *JavaOptsFramework) Supply() error {
	// Java Opts framework only configures environment in finalize phase
	return nil
}

// Finalize applies the JAVA_OPTS configuration
func (j *JavaOptsFramework) Finalize() error {
	j.context.Log.BeginStep("Configuring Java Opts")

	// Load configuration
	config, err := j.loadConfig()
	if err != nil {
		j.context.Log.Warning("Failed to load java_opts config: %s", err.Error())
		return nil // Don't fail the build
	}

	var javaOpts []string

	// Add configured java_opts from config file
	if len(config.JavaOpts) > 0 {
		j.context.Log.Info("Adding configured JAVA_OPTS: %v", config.JavaOpts)
		javaOpts = append(javaOpts, config.JavaOpts...)
	}

	// Add $JAVA_OPTS from environment if from_environment is true
	if config.FromEnvironment {
		j.context.Log.Info("Including JAVA_OPTS from environment at runtime")
		// Add a placeholder that will be expanded at runtime in the startup script
		javaOpts = append(javaOpts, "${JAVA_OPTS}")
	}

	// If no opts to add, skip
	if len(javaOpts) == 0 {
		j.context.Log.Info("No JAVA_OPTS to configure")
		return nil
	}

	// Join all opts into a single string
	optsString := strings.Join(javaOpts, " ")

	// Append to existing JAVA_OPTS environment file (don't overwrite)
	if err := j.context.Stager.WriteEnvFile("JAVA_OPTS", optsString); err != nil {
		return fmt.Errorf("failed to set JAVA_OPTS: %w", err)
	}

	j.context.Log.Info("Configured JAVA_OPTS")
	return nil
}

// loadConfig loads the java_opts.yml configuration
func (j *JavaOptsFramework) loadConfig() (*JavaOptsConfig, error) {
	config := &JavaOptsConfig{
		FromEnvironment: true, // Default to true (matches config file)
		JavaOpts:        []string{},
	}

	// Check for JBP_CONFIG_JAVA_OPTS override
	configOverride := os.Getenv("JBP_CONFIG_JAVA_OPTS")
	if configOverride != "" {
		// First, parse the outer YAML string (handles single-quoted format like '{...}')
		var yamlContent interface{}
		if err := yaml.Unmarshal([]byte(configOverride), &yamlContent); err != nil {
			return nil, fmt.Errorf("failed to parse JBP_CONFIG_JAVA_OPTS: %w", err)
		}

		// Handle different YAML formats for backward compatibility
		var configData []byte
		switch v := yamlContent.(type) {
		case string:
			// It's a YAML string literal - parse the content
			configData = []byte(v)
		case map[interface{}]interface{}:
			// It's already a parsed YAML structure - marshal it back to bytes
			var err error
			configData, err = yaml.Marshal(v)
			if err != nil {
				return nil, fmt.Errorf("failed to marshal config map: %w", err)
			}
		case []interface{}:
			// Handle legacy format: [from_environment: false, java_opts: ...]
			// This parses as an array of maps, so we need to merge them
			mergedMap := make(map[interface{}]interface{})
			for _, item := range v {
				if m, ok := item.(map[interface{}]interface{}); ok {
					for k, val := range m {
						mergedMap[k] = val
					}
				}
			}
			var err error
			configData, err = yaml.Marshal(mergedMap)
			if err != nil {
				return nil, fmt.Errorf("failed to marshal merged config map: %w", err)
			}
		default:
			return nil, fmt.Errorf("unexpected YAML type: %T", v)
		}

		// Parse into a generic map first to handle both string and array formats for java_opts
		var rawConfig map[string]interface{}
		if err := yaml.Unmarshal(configData, &rawConfig); err != nil {
			return nil, fmt.Errorf("failed to parse JBP_CONFIG_JAVA_OPTS structure: %w", err)
		}

		// Handle from_environment field
		if fromEnv, ok := rawConfig["from_environment"].(bool); ok {
			config.FromEnvironment = fromEnv
		}

		// Handle java_opts field - support both string and array formats
		if javaOptsRaw, ok := rawConfig["java_opts"]; ok {
			switch opts := javaOptsRaw.(type) {
			case []interface{}:
				// Already an array
				for _, opt := range opts {
					if optStr, ok := opt.(string); ok {
						config.JavaOpts = append(config.JavaOpts, optStr)
					}
				}
			case string:
				// Legacy format: space-separated string
				// Split on spaces but preserve quoted strings
				if opts != "" {
					config.JavaOpts = strings.Fields(opts)
				}
			}
		}

		return config, nil
	}

	// Load from config file (java_opts.yml)
	configPath := j.context.Manifest.RootDir() + "/config/java_opts.yml"
	data, err := os.ReadFile(configPath)
	if err != nil {
		// Config file not found is OK - use defaults
		return config, nil
	}

	if err := yaml.Unmarshal(data, config); err != nil {
		return nil, fmt.Errorf("failed to parse java_opts.yml: %w", err)
	}

	return config, nil
}
