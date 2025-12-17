package frameworks

import (
	"fmt"
	"os"
	"strings"
	"unicode"

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

	var configuredOpts []string

	// Add configured java_opts from config file
	if len(config.JavaOpts) > 0 {
		j.context.Log.Info("Adding configured JAVA_OPTS: %v", config.JavaOpts)
		configuredOpts = append(configuredOpts, config.JavaOpts...)
	}

	// Build the configured JAVA_OPTS value
	// Escape each opt using Ruby buildpack's strategy: backslash-escape special characters
	// This allows values with spaces to be preserved when passed through shell evaluation
	var escapedOpts []string
	for _, opt := range configuredOpts {
		escapedOpts = append(escapedOpts, rubyStyleEscape(opt))
	}
	optsString := strings.Join(escapedOpts, " ")

	// Write user-defined JAVA_OPTS to .opts file with priority 99 (Ruby buildpack line 82)
	// This ensures user opts run LAST, allowing them to override framework defaults
	//
	// Handle from_environment setting:
	// - If true: prepend $JAVA_OPTS (from environment) before user opts
	// - If false: only use configured opts (ignore environment JAVA_OPTS)
	var finalOpts string
	if config.FromEnvironment {
		// Preserve user's JAVA_OPTS from environment and append configured opts
		if optsString != "" {
			finalOpts = fmt.Sprintf("$JAVA_OPTS %s", optsString)
		} else {
			// No configured opts, use environment JAVA_OPTS
			finalOpts = "$JAVA_OPTS"
		}
	} else {
		// Ignore environment JAVA_OPTS, use only configured opts
		finalOpts = optsString
	}

	// Write to .opts file (priority 99 = always last)
	if finalOpts != "" {
		if err := writeJavaOptsFile(j.context, 99, "user_java_opts", finalOpts); err != nil {
			return fmt.Errorf("failed to write java_opts file: %w", err)
		}
	}

	j.context.Log.Info("Configured user JAVA_OPTS for runtime (priority 99)")
	return nil
}

// shellSplit splits a string like a shell would, respecting quotes
// Similar to Ruby's Shellwords.shellsplit
func shellSplit(input string) ([]string, error) {
	var tokens []string
	var current strings.Builder
	var inSingleQuote, inDoubleQuote bool
	var escaped bool

	for _, r := range input {
		// Handle escape sequences
		if escaped {
			current.WriteRune(r)
			escaped = false
			continue
		}

		if r == '\\' {
			escaped = true
			continue
		}

		// Handle quotes
		if r == '\'' && !inDoubleQuote {
			inSingleQuote = !inSingleQuote
			continue
		}

		if r == '"' && !inSingleQuote {
			inDoubleQuote = !inDoubleQuote
			continue
		}

		// Handle spaces (word separators when not quoted)
		if unicode.IsSpace(r) && !inSingleQuote && !inDoubleQuote {
			if current.Len() > 0 {
				tokens = append(tokens, current.String())
				current.Reset()
			}
			continue
		}

		// Regular character
		current.WriteRune(r)
	}

	// Add last token if exists
	if current.Len() > 0 {
		tokens = append(tokens, current.String())
	}

	// Check for unclosed quotes
	if inSingleQuote || inDoubleQuote {
		return nil, fmt.Errorf("unclosed quote in string: %s", input)
	}

	return tokens, nil
}

// rubyStyleEscape escapes a Java option exactly like the Ruby buildpack
//
// Ruby source: lib/java_buildpack/framework/java_opts.rb:40-41
//
//	.map { |java_opt| /(?<key>.+?)=(?<value>.+)/ =~ java_opt ? "#{key}=#{escape_value(value)}" : java_opt }
//
// Strategy: Split on first '=' and escape only the VALUE part
//
// Examples:
//
//	"-Xmx512M"                          → "-Xmx512M"
//	"-Dkey=value with spaces"           → "-Dkey=value\\ with\\ spaces"
//	"-XX:OnOutOfMemoryError=kill -9 %p" → "-XX:OnOutOfMemoryError=kill\\ -9\\ \\%p"
func rubyStyleEscape(javaOpt string) string {
	idx := strings.IndexByte(javaOpt, '=')

	if idx == -1 || idx == len(javaOpt)-1 {
		return javaOpt // No '=' or ends with '='
	}

	key := javaOpt[:idx]
	value := javaOpt[idx+1:]

	return key + "=" + escapeValue(value)
}

// escapeValue escapes a string for shell safety using Ruby's escape_value method
//
// Ruby source: lib/java_buildpack/framework/java_opts.rb:61-67
//
//	str.gsub(%r{([^A-Za-z0-9_\-.,:/@\n$\\])}, '\\\\\\1').gsub(/\n/, "'\n'")
//
// Safe chars (not escaped): A-Za-z0-9_-.,:/@$\
// All other chars are backslash-escaped, including: = ( ) [ ] { } ; & | space % etc.
func escapeValue(value string) string {
	if value == "" {
		return "''"
	}

	var result strings.Builder
	for _, ch := range value {
		if ch == '\n' {
			result.WriteString("'\n'") // Special newline handling
			continue
		}

		if !isRubySafeChar(ch) {
			result.WriteRune('\\')
		}
		result.WriteRune(ch)
	}
	return result.String()
}

// isRubySafeChar checks if a character is in Ruby's safe set: A-Za-z0-9_-.,:/@\n$\
// Note: '=' is NOT safe and will be escaped
func isRubySafeChar(ch rune) bool {
	return (ch >= 'A' && ch <= 'Z') ||
		(ch >= 'a' && ch <= 'z') ||
		(ch >= '0' && ch <= '9') ||
		ch == '_' ||
		ch == '-' ||
		ch == '.' ||
		ch == ',' ||
		ch == ':' ||
		ch == '/' ||
		ch == '@' ||
		ch == '\n' ||
		ch == '$' ||
		ch == '\\'
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
				// Split on spaces but preserve quoted strings (like Ruby's shellsplit)
				if opts != "" {
					tokens, err := shellSplit(opts)
					if err != nil {
						return nil, fmt.Errorf("failed to parse java_opts string: %w", err)
					}
					config.JavaOpts = tokens
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
