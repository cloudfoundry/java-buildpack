package common

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/cloudfoundry/libbuildpack"
)

// Context holds shared dependencies for buildpack components
// Used by containers, frameworks, and JREs to access buildpack infrastructure
type Context struct {
	Stager    *libbuildpack.Stager
	Manifest  *libbuildpack.Manifest
	Installer *libbuildpack.Installer
	Log       *libbuildpack.Logger
	Command   *libbuildpack.Command
}

// DetermineJavaVersion determines the major Java version from a Java installation
// by reading the JAVA_VERSION field from the release file.
//
// Parameters:
//   - javaHome: Path to the Java installation (e.g., /deps/0/jre)
//
// Returns the major version (8, 11, 17, etc.) or an error if unable to determine.
//
// Example:
//
//	version, err := DetermineJavaVersion("/deps/0/jre")
func DetermineJavaVersion(javaHome string) (int, error) {

	releaseFile := filepath.Join(javaHome, "release")
	content, err := os.ReadFile(releaseFile)
	if err != nil {
		return 0, fmt.Errorf("failed to read release file: %w", err)
	}

	// Parse JAVA_VERSION from release file
	// Format: JAVA_VERSION="1.8.0_422" or JAVA_VERSION="17.0.13"
	lines := strings.Split(string(content), "\n")
	for _, line := range lines {
		if !strings.HasPrefix(line, "JAVA_VERSION=") {
			continue
		}

		// Extract version string from JAVA_VERSION="..."
		version := strings.Trim(strings.TrimPrefix(line, "JAVA_VERSION="), "\"")

		// Handle Java 7/8 format: 1.8.x or 1.7.x
		if strings.HasPrefix(version, "1.8") {
			return 8, nil
		}
		if strings.HasPrefix(version, "1.7") {
			return 7, nil
		}

		// Handle Java 9+ format: major version is first number
		// Examples: "11.0.1", "17.0.13", "21.0.1"
		dotIndex := strings.Index(version, ".")
		if dotIndex > 0 {
			majorStr := version[:dotIndex]
			if major, err := strconv.Atoi(majorStr); err == nil {
				return major, nil
			}
		}
	}

	return 0, fmt.Errorf("unable to parse Java version from release file")
}

// GetJavaMajorVersion returns the Java major version from the JAVA_HOME environment variable.
// This is a convenience wrapper around DetermineJavaVersion that reads JAVA_HOME from the environment.
//
// Returns the major version (8, 11, 17, etc.) or an error if JAVA_HOME is not set
// or the version cannot be determined.
//
// Example:
//
//	version, err := GetJavaMajorVersion()
func GetJavaMajorVersion() (int, error) {
	javaHome := os.Getenv("JAVA_HOME")
	if javaHome == "" {
		return 0, fmt.Errorf("JAVA_HOME not set")
	}
	return DetermineJavaVersion(javaHome)
}

// VCAPServices represents the VCAP_SERVICES environment variable structure
// This is a map of service labels to arrays of service instances
type VCAPServices map[string][]VCAPService

// VCAPService represents a single Cloud Foundry service binding
type VCAPService struct {
	Name        string                 `json:"name"`
	Label       string                 `json:"label"`
	Tags        []string               `json:"tags"`
	Credentials map[string]interface{} `json:"credentials"`
}

// GetVCAPServices parses the VCAP_SERVICES environment variable
// Returns an empty VCAPServices map if VCAP_SERVICES is not set
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
// Returns nil if no service with the label exists
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
// Pattern matching is case-insensitive substring matching
func (v VCAPServices) HasServiceByNamePattern(pattern string) bool {
	return v.GetServiceByNamePattern(pattern) != nil
}

// GetServiceByNamePattern returns the first service in "user-provided" that matches the pattern
// Returns nil if no matching service is found
// Pattern matching is case-insensitive substring matching (e.g., "newrelic" matches "my-newrelic-service")
func (v VCAPServices) GetServiceByNamePattern(pattern string) *VCAPService {
	userProvided, exists := v["user-provided"]
	if !exists {
		return nil
	}

	// Case-insensitive substring matching
	patternLower := strings.ToLower(pattern)
	for _, service := range userProvided {
		if strings.Contains(strings.ToLower(service.Name), patternLower) {
			return &service
		}
	}

	return nil
}

// HasTag checks if this service has the specified tag
func (s *VCAPService) HasTag(tag string) bool {
	for _, t := range s.Tags {
		if t == tag {
			return true
		}
	}
	return false
}

// ContainsIgnoreCase checks if string s contains substr (case-insensitive)
// This is a utility function used by frameworks for flexible matching
func ContainsIgnoreCase(s, substr string) bool {
	return strings.Contains(strings.ToLower(s), strings.ToLower(substr))
}
