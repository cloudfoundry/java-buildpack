package frameworks

import (
	"encoding/json"
	"os"

	"github.com/cloudfoundry/libbuildpack"
)

// Framework represents a cross-cutting concern (APM agents, security providers, etc.)
type Framework interface {
	// Detect returns true if this framework should be included
	// Returns the framework name and version if detected
	Detect() (string, error)

	// Supply installs the framework
	Supply() error

	// Finalize performs final framework configuration
	Finalize() error
}

// Context holds common dependencies for frameworks
type Context struct {
	Stager    *libbuildpack.Stager
	Manifest  *libbuildpack.Manifest
	Installer *libbuildpack.Installer
	Log       *libbuildpack.Logger
	Command   *libbuildpack.Command
}

// Registry manages available frameworks
type Registry struct {
	frameworks []Framework
	context    *Context
}

// NewRegistry creates a new framework registry
func NewRegistry(ctx *Context) *Registry {
	return &Registry{
		frameworks: []Framework{},
		context:    ctx,
	}
}

// Register adds a framework to the registry
func (r *Registry) Register(f Framework) {
	r.frameworks = append(r.frameworks, f)
}

// DetectAll returns all frameworks that should be included
func (r *Registry) DetectAll() ([]Framework, []string, error) {
	var matched []Framework
	var names []string

	for _, framework := range r.frameworks {
		if name, err := framework.Detect(); err == nil && name != "" {
			matched = append(matched, framework)
			names = append(names, name)
		}
	}

	return matched, names, nil
}

// VCAPServices represents the VCAP_SERVICES environment variable structure
type VCAPServices map[string][]VCAPService

// VCAPService represents a single service binding
type VCAPService struct {
	Name        string                 `json:"name"`
	Label       string                 `json:"label"`
	Tags        []string               `json:"tags"`
	Credentials map[string]interface{} `json:"credentials"`
}

// GetVCAPServices parses the VCAP_SERVICES environment variable
func GetVCAPServices() (VCAPServices, error) {
	vcapServicesStr := os.Getenv("VCAP_SERVICES")
	if vcapServicesStr == "" {
		return VCAPServices{}, nil
	}

	var services VCAPServices
	if err := json.Unmarshal([]byte(vcapServicesStr), &services); err != nil {
		return nil, err
	}

	return services, nil
}

// HasService checks if a service with the given label exists
func (v VCAPServices) HasService(label string) bool {
	_, exists := v[label]
	return exists
}

// GetService returns the first service with the given label
func (v VCAPServices) GetService(label string) *VCAPService {
	services, exists := v[label]
	if !exists || len(services) == 0 {
		return nil
	}
	return &services[0]
}

// HasTag checks if any service has the given tag
func (v VCAPServices) HasTag(tag string) bool {
	for _, serviceList := range v {
		for _, service := range serviceList {
			for _, t := range service.Tags {
				if t == tag {
					return true
				}
			}
		}
	}
	return false
}

// HasServiceByNamePattern checks if any service in "user-provided" matches the pattern
// This is needed for Docker platform where services are under "user-provided" label
func (v VCAPServices) HasServiceByNamePattern(pattern string) bool {
	userProvided, exists := v["user-provided"]
	if !exists {
		return false
	}

	for _, service := range userProvided {
		// Check if service name contains the pattern (case-insensitive)
		// Pattern examples: "newrelic", "appdynamics", "dynatrace"
		if matchesPattern(service.Name, pattern) {
			return true
		}
	}
	return false
}

// GetServiceByNamePattern returns the first service in "user-provided" matching the pattern
func (v VCAPServices) GetServiceByNamePattern(pattern string) *VCAPService {
	userProvided, exists := v["user-provided"]
	if !exists {
		return nil
	}

	for _, service := range userProvided {
		if matchesPattern(service.Name, pattern) {
			return &service
		}
	}
	return nil
}

// matchesPattern checks if a service name matches a pattern
// Pattern matching is case-insensitive and checks for substring match
func matchesPattern(serviceName, pattern string) bool {
	// Simple substring match - case insensitive
	// Examples: "newrelic" matches "newrelic", "my-newrelic-service", "newrelic-prod"
	return containsIgnoreCase(serviceName, pattern)
}

// containsIgnoreCase checks if s contains substr (case-insensitive)
func containsIgnoreCase(s, substr string) bool {
	sLower := toLower(s)
	substrLower := toLower(substr)
	return stringContains(sLower, substrLower)
}

// toLower converts string to lowercase (simplified implementation)
func toLower(s string) string {
	result := make([]byte, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c >= 'A' && c <= 'Z' {
			result[i] = c + 32
		} else {
			result[i] = c
		}
	}
	return string(result)
}

// stringContains checks if s contains substr
func stringContains(s, substr string) bool {
	if len(substr) == 0 {
		return true
	}
	if len(s) < len(substr) {
		return false
	}
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

// AppendToJavaOpts appends a value to JAVA_OPTS environment variable, preserving existing values.
// This function ensures that multiple frameworks can add their options without overwriting each other.
//
// During the Supply phase, frameworks write to env/JAVA_OPTS file which is then sourced by
// Cloud Foundry between buildpack phases. This helper reads the current JAVA_OPTS from the
// process environment (set by previous frameworks), appends the new value, and writes it back.
//
// Parameters:
//   - ctx: Framework context containing Stager for writing env files
//   - value: The JAVA_OPTS value to append (e.g., "-javaagent:/path/to/agent.jar")
//
// Returns error if writing the env file fails.
//
// Example usage:
//
//	if err := AppendToJavaOpts(ctx, "-javaagent:/deps/0/agent.jar"); err != nil {
//	    return fmt.Errorf("failed to set JAVA_OPTS: %w", err)
//	}
func AppendToJavaOpts(ctx *Context, value string) error {
	if value == "" {
		return nil // Nothing to append
	}

	// Read existing JAVA_OPTS from environment
	// During Supply phase, this reflects what previous frameworks have written
	existingOpts := os.Getenv("JAVA_OPTS")

	// Build combined JAVA_OPTS
	var combinedOpts string
	if existingOpts != "" {
		combinedOpts = existingOpts + " " + value
	} else {
		combinedOpts = value
	}

	// Write to env file for next buildpack phase and subsequent frameworks
	if err := ctx.Stager.WriteEnvFile("JAVA_OPTS", combinedOpts); err != nil {
		return err
	}

	// Also update the current process environment so subsequent frameworks
	// in the same phase can read the accumulated value
	return os.Setenv("JAVA_OPTS", combinedOpts)
}
