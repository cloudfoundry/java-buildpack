package frameworks

import (
	"encoding/json"
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"os"
	"path/filepath"
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

// Registry manages available frameworks
type Registry struct {
	frameworks []Framework
	context    *common.Context
}

// NewRegistry creates a new framework registry
func NewRegistry(ctx *common.Context) *Registry {
	return &Registry{
		frameworks: []Framework{},
		context:    ctx,
	}
}

// Register adds a framework to the registry
func (r *Registry) Register(f Framework) {
	r.frameworks = append(r.frameworks, f)
}

// RegisterStandardFrameworks registers all standard frameworks in the correct priority order.
// This ensures Supply and Finalize phases use the same detection order.
// IMPORTANT: The order matters! Frameworks are checked in registration order.
func (r *Registry) RegisterStandardFrameworks() {
	// APM Agents (Priority 1)
	r.Register(NewNewRelicFramework(r.context))
	r.Register(NewAppDynamicsFramework(r.context))
	r.Register(NewDynatraceFramework(r.context))
	r.Register(NewDatadogJavaagentFramework(r.context))
	r.Register(NewElasticApmAgentFramework(r.context))

	// Spring Service Bindings (Priority 1)
	r.Register(NewSpringAutoReconfigurationFramework(r.context))
	r.Register(NewJavaCfEnvFramework(r.context))

	// JDBC Drivers (Priority 1)
	r.Register(NewPostgresqlJdbcFramework(r.context))
	r.Register(NewMariaDBJDBCFramework(r.context))

	// mTLS Support (Priority 1)
	r.Register(NewClientCertificateMapperFramework(r.context))

	// Security Providers (Priority 1)
	r.Register(NewContainerSecurityProviderFramework(r.context))
	r.Register(NewLunaSecurityProviderFramework(r.context))
	r.Register(NewProtectAppSecurityProviderFramework(r.context))
	r.Register(NewSeekerSecurityProviderFramework(r.context))

	// Container & Runtime Support (Priority 1)
	r.Register(NewContainerCustomizerFramework(r.context))
	r.Register(NewJavaMemoryAssistantFramework(r.context))

	// Metrics & Observability (Priority 1)
	r.Register(NewMetricWriterFramework(r.context))

	// Development Tools (Priority 1)
	r.Register(NewDebugFramework(r.context))
	r.Register(NewJmxFramework(r.context))
	r.Register(NewJavaOptsFramework(r.context))

	// APM Agents (Priority 2)
	r.Register(NewAzureApplicationInsightsAgentFramework(r.context))
	r.Register(NewCheckmarxIASTAgentFramework(r.context))
	r.Register(NewGoogleStackdriverDebuggerFramework(r.context))
	r.Register(NewGoogleStackdriverProfilerFramework(r.context))
	r.Register(NewIntroscopeAgentFramework(r.context))
	r.Register(NewOpenTelemetryJavaagentFramework(r.context))
	r.Register(NewRiverbedAppInternalsAgentFramework(r.context))
	r.Register(NewSkyWalkingAgentFramework(r.context))
	r.Register(NewSplunkOtelJavaAgentFramework(r.context))

	// Testing & Code Coverage (Priority 3)
	r.Register(NewJacocoAgentFramework(r.context))

	// Code Instrumentation & Additional Development Tools (Priority 3)
	r.Register(NewJRebelAgentFramework(r.context))
	r.Register(NewContrastSecurityAgentFramework(r.context))
	r.Register(NewAspectJWeaverAgentFramework(r.context))
	r.Register(NewTakipiAgentFramework(r.context))
	r.Register(NewYourKitProfilerFramework(r.context))
	r.Register(NewJProfilerProfilerFramework(r.context))
	r.Register(NewSealightsAgentFramework(r.context))
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

// GetApplicationName returns the application name from VCAP_APPLICATION.
// If includeSpace is true, returns "space_name:application_name" format,
// falling back to just "application_name" if space is not available.
// Returns empty string if application name is not available.
func GetApplicationName(includeSpace bool) string {
	vcapApp := os.Getenv("VCAP_APPLICATION")
	if vcapApp == "" {
		return ""
	}

	var appData map[string]interface{}
	if err := json.Unmarshal([]byte(vcapApp), &appData); err != nil {
		return ""
	}

	appName, hasApp := appData["application_name"].(string)
	if !hasApp {
		return ""
	}

	if includeSpace {
		if spaceName, hasSpace := appData["space_name"].(string); hasSpace {
			return spaceName + ":" + appName
		}
	}

	return appName
}

// FindFileInDirectory searches for a file by name in a directory, checking common
// locations first and then recursively searching if not found.
// Returns the full path to the file or an error if not found.
//
// Parameters:
//   - baseDir: The directory to search in
//   - filename: The exact filename to search for (e.g., "javaagent.jar", "libjprofilerti.so")
//   - commonSubdirs: Optional subdirectories to check first (e.g., ["lib", "bin/linux-x64"])
//
// Example:
//
//	agentPath, err := FindFileInDirectory(installDir, "javaagent.jar", []string{"", "lib"})
func FindFileInDirectory(baseDir, filename string, commonSubdirs []string) (string, error) {
	return FindFileInDirectoryWithArchFilter(baseDir, filename, commonSubdirs, nil)
}

// FindFileInDirectoryWithArchFilter searches for a file by name in a directory with optional
// architecture filtering. This is useful when archives contain multiple platform versions
// (e.g., linux-aarch64, linux-amd64, linux-x64) and you need to ensure the correct one.
//
// Parameters:
//   - baseDir: The directory to search in
//   - filename: The exact filename to search for
//   - commonSubdirs: Optional subdirectories to check first
//   - archDirs: Optional list of valid parent directory names (e.g., ["linux-x64", "linux-amd64"]).
//     If nil, any parent directory is accepted.
//
// Example:
//
//	agentPath, err := FindFileInDirectoryWithArchFilter(installDir, "libjprofilerti.so",
//	    []string{"bin/linux-x64", "bin/linux-amd64"}, []string{"linux-x64", "linux-amd64"})
func FindFileInDirectoryWithArchFilter(baseDir, filename string, commonSubdirs []string, archDirs []string) (string, error) {
	// Helper to check if a path's parent dir matches archDirs filter
	matchesArchFilter := func(path string) bool {
		if archDirs == nil || len(archDirs) == 0 {
			return true // No filter, accept all
		}
		parentDir := filepath.Base(filepath.Dir(path))
		for _, validArch := range archDirs {
			if parentDir == validArch {
				return true
			}
		}
		return false
	}

	// Check common locations first
	for _, subdir := range commonSubdirs {
		path := filepath.Join(baseDir, subdir, filename)
		if _, err := os.Stat(path); err == nil && matchesArchFilter(path) {
			return path, nil
		}
	}

	// Check with glob patterns for versioned directories (e.g., "ver*/javaagent.jar")
	for _, subdir := range commonSubdirs {
		pattern := filepath.Join(baseDir, subdir, "*", filename)
		matches, _ := filepath.Glob(pattern)
		for _, match := range matches {
			if _, err := os.Stat(match); err == nil && matchesArchFilter(match) {
				return match, nil
			}
		}
	}

	// Search recursively as fallback
	var foundPath string
	filepath.Walk(baseDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // Continue walking on errors
		}
		if !info.IsDir() && info.Name() == filename && matchesArchFilter(path) {
			foundPath = path
			return filepath.SkipAll
		}
		return nil
	})

	if foundPath != "" {
		return foundPath, nil
	}

	archMsg := ""
	if archDirs != nil && len(archDirs) > 0 {
		archMsg = fmt.Sprintf(" (matching arch: %v)", archDirs)
	}
	return "", fmt.Errorf("%s not found in %s%s", filename, baseDir, archMsg)
}

// FindFileByPattern searches for a file matching a glob pattern in a directory.
// Returns the first matching file or an error if not found.
//
// Parameters:
//   - baseDir: The directory to search in
//   - pattern: The glob pattern to match (e.g., "contrast*.jar", "sl-test-listener*.jar")
//   - commonSubdirs: Optional subdirectories to check first
//
// Example:
//
//	agentPath, err := FindFileByPattern(installDir, "contrast*.jar", []string{""})
func FindFileByPattern(baseDir, pattern string, commonSubdirs []string) (string, error) {
	// Check common locations first
	for _, subdir := range commonSubdirs {
		globPattern := filepath.Join(baseDir, subdir, pattern)
		matches, _ := filepath.Glob(globPattern)
		if len(matches) > 0 {
			return matches[0], nil
		}
	}

	// Search recursively as fallback
	var foundPath string
	filepath.Walk(baseDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if !info.IsDir() {
			matched, _ := filepath.Match(pattern, info.Name())
			if matched {
				foundPath = path
				return filepath.SkipAll
			}
		}
		return nil
	})

	if foundPath != "" {
		return foundPath, nil
	}

	return "", fmt.Errorf("no file matching %s found in %s", pattern, baseDir)
}
