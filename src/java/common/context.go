package common

import (
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
