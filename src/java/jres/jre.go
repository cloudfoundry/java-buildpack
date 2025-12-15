package jres

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/libbuildpack"
)

// JRE represents a Java Runtime Environment provider
type JRE interface {
	// Name returns the name of this JRE provider (e.g., "OpenJDK", "Zulu")
	Name() string

	// Detect returns true if this JRE should be used
	Detect() (bool, error)

	// Supply installs the JRE and its components (memory calculator, jvmkill)
	Supply() error

	// Finalize performs any final JRE configuration
	Finalize() error

	// JavaHome returns the path to JAVA_HOME
	JavaHome() string

	// Version returns the installed JRE version
	Version() string
}

// Context holds shared dependencies for JRE providers
type Context struct {
	Stager    *libbuildpack.Stager
	Manifest  *libbuildpack.Manifest
	Installer *libbuildpack.Installer
	Log       *libbuildpack.Logger
	Command   *libbuildpack.Command
}

// Registry manages multiple JRE providers
type Registry struct {
	ctx        *Context
	providers  []JRE
	defaultJRE JRE
}

// NewRegistry creates a new JRE registry
func NewRegistry(ctx *Context) *Registry {
	return &Registry{
		ctx:       ctx,
		providers: []JRE{},
	}
}

// Register adds a JRE provider to the registry
func (r *Registry) Register(jre JRE) {
	r.providers = append(r.providers, jre)
}

// SetDefault sets the default JRE to use when no JRE is explicitly configured
func (r *Registry) SetDefault(jre JRE) {
	r.defaultJRE = jre
}

// Detect finds the JRE provider that should be used
// If a JRE is explicitly configured, it uses that JRE and fails if detection errors
// If no JRE is explicitly configured, it uses the configured default JRE
// Returns the JRE, its name, and any error
func (r *Registry) Detect() (JRE, string, error) {
	var detectionErrors []error

	// Check if any JRE is explicitly configured
	for _, jre := range r.providers {
		detected, err := jre.Detect()
		if err != nil {
			// Collect detection errors - if a JRE is explicitly configured but fails to detect,
			// we should fail the build rather than silently falling back to the default
			detectionErrors = append(detectionErrors, fmt.Errorf("%s: %w", jre.Name(), err))
			continue
		}
		if detected {
			return jre, jre.Name(), nil
		}
	}

	// If we had detection errors, fail the build
	// This ensures explicit JRE configurations don't silently fall back to defaults
	if len(detectionErrors) > 0 {
		r.ctx.Log.Error("JRE detection errors occurred:")
		for _, err := range detectionErrors {
			r.ctx.Log.Error("  - %s", err.Error())
		}
		return nil, "", fmt.Errorf("JRE detection failed with %d error(s)", len(detectionErrors))
	}

	// No explicit configuration found, use default JRE
	if r.defaultJRE != nil {
		r.ctx.Log.Info("No JRE explicitly configured, using default: %s", r.defaultJRE.Name())
		return r.defaultJRE, r.defaultJRE.Name(), nil
	}

	// No default JRE configured
	return nil, "", fmt.Errorf("no JRE found and no default JRE configured")
}

// Component represents a JRE component (memory calculator, jvmkill, etc.)
type Component interface {
	// Name returns the component name
	Name() string

	// Supply installs the component
	Supply() error

	// Finalize performs final configuration
	Finalize() error
}

// BaseComponent provides common functionality for JRE components
type BaseComponent struct {
	Ctx         *Context
	JREDir      string
	JREVersion  string
	ComponentID string
}

// Memory calculator constants
const (
	DefaultStackThreads = 250
	DefaultHeadroom     = 0
	Java9ClassCount     = 42215 // Classes in Java 9+ JRE
)

// Helper functions

// DetectJREByEnv checks environment variables for JRE selection
// Supports JBP_CONFIG_OPEN_JDK_JRE, etc.
func DetectJREByEnv(jreName string) bool {
	envKey := fmt.Sprintf("JBP_CONFIG_%s", strings.ToUpper(strings.ReplaceAll(jreName, "-", "_")))
	return os.Getenv(envKey) != ""
}

// GetJREVersion gets the desired JRE version from environment or uses default
// Supports BP_JAVA_VERSION (simple version) and JBP_CONFIG_<JRE_NAME> (complex config)
func GetJREVersion(ctx *Context, jreName string) (libbuildpack.Dependency, error) {
	// Check for simple BP_JAVA_VERSION environment variable first
	// Format: "8", "11", "17", "21", etc. or version patterns like "11.+", "17.*"
	if bpVersion := os.Getenv("BP_JAVA_VERSION"); bpVersion != "" {
		ctx.Log.Debug("Using Java version from BP_JAVA_VERSION: %s", bpVersion)

		// Normalize version to a pattern that FindMatchingVersion understands
		versionPattern := normalizeVersionPattern(bpVersion)

		// Get all available versions for this JRE
		availableVersions := ctx.Manifest.AllDependencyVersions(jreName)
		if len(availableVersions) == 0 {
			return libbuildpack.Dependency{}, fmt.Errorf("no versions found for %s", jreName)
		}

		// Find the highest matching version
		matchedVersion, err := libbuildpack.FindMatchingVersion(versionPattern, availableVersions)
		if err != nil {
			ctx.Log.Warning("Could not find %s matching version %s: %s", jreName, versionPattern, err.Error())
			return libbuildpack.Dependency{}, fmt.Errorf("no version of %s matching %s found", jreName, versionPattern)
		}

		ctx.Log.Debug("Resolved %s version %s from pattern %s", jreName, matchedVersion, versionPattern)
		return libbuildpack.Dependency{Name: jreName, Version: matchedVersion}, nil
	}

	// Check for legacy JBP_CONFIG_<JRE_NAME> environment variable
	envKey := fmt.Sprintf("JBP_CONFIG_%s", strings.ToUpper(strings.ReplaceAll(jreName, "-", "_")))
	if envVal := os.Getenv(envKey); envVal != "" {
		// Parse version from env (e.g., '{jre: {version: 11.+}}')
		// For now, simplified - just log it
		ctx.Log.Debug("JRE version override from %s: %s", envKey, envVal)
		// TODO: Parse YAML-like config from envVal
	}

	// Get default version from manifest (no version constraint)
	dep, err := ctx.Manifest.DefaultVersion(jreName)
	if err != nil {
		return libbuildpack.Dependency{}, err
	}

	return dep, nil
}

// normalizeVersionPattern converts user-friendly version strings to manifest patterns
// Examples: "8" -> "8.*", "11" -> "11.*", "17.0" -> "17.0.*", "11.+" -> "11.+"
func normalizeVersionPattern(version string) string {
	// If already has wildcard, return as-is
	if strings.Contains(version, "*") || strings.Contains(version, "+") {
		return version
	}

	// Otherwise append ".*" to match any patch version
	return version + ".*"
}

// DetermineJavaVersion determines the major Java version from the installed JRE
func DetermineJavaVersion(javaHome string) (int, error) {
	// Try to read release file
	releaseFile := filepath.Join(javaHome, "release")
	if data, err := os.ReadFile(releaseFile); err == nil {
		// Parse JAVA_VERSION="1.8.0_422" or JAVA_VERSION="17.0.13"
		content := string(data)
		for _, line := range strings.Split(content, "\n") {
			if strings.HasPrefix(line, "JAVA_VERSION=") {
				version := strings.Trim(strings.TrimPrefix(line, "JAVA_VERSION="), "\"")
				// Parse major version
				if strings.HasPrefix(version, "1.8") {
					return 8, nil
				}
				// For Java 9+, major version is the first number
				parts := strings.Split(version, ".")
				if len(parts) > 0 {
					var major int
					fmt.Sscanf(parts[0], "%d", &major)
					return major, nil
				}
			}
		}
	}

	// Default to 17 if we can't determine
	return 17, nil
}

// WriteJavaOpts writes JAVA_OPTS to a profile.d script for runtime export
func WriteJavaOpts(ctx *Context, opts string) error {
	profileDir := filepath.Join(ctx.Stager.BuildDir(), ".profile.d")
	if err := os.MkdirAll(profileDir, 0755); err != nil {
		return fmt.Errorf("failed to create .profile.d directory: %w", err)
	}

	profileScript := filepath.Join(profileDir, "java_opts.sh")

	// Append to existing JAVA_OPTS if file exists
	var scriptContent string
	if existing, err := os.ReadFile(profileScript); err == nil {
		// File exists - extract current JAVA_OPTS value and append
		scriptContent = string(existing)
		// Remove the trailing newline if present
		scriptContent = strings.TrimSuffix(scriptContent, "\n")
		// Append new opts to the export line
		scriptContent = strings.Replace(scriptContent, "${JAVA_OPTS:-}", "${JAVA_OPTS:-} "+opts, 1)
		scriptContent += "\n"
	} else {
		// Create new profile.d script with export statement
		scriptContent = fmt.Sprintf("export JAVA_OPTS=\"${JAVA_OPTS:-%s}\"\n", opts)
	}

	if err := os.WriteFile(profileScript, []byte(scriptContent), 0755); err != nil {
		return fmt.Errorf("failed to write profile.d/java_opts.sh: %w", err)
	}

	return nil
}

// WriteJavaHomeProfileD creates a profile.d script that exports JAVA_HOME, JRE_HOME, and PATH at runtime
// This is needed for containers that use startup scripts expecting $JAVA_HOME environment variable
//
// Parameters:
//   - ctx: JRE context with Stager and Logger
//   - jreDir: The directory where the JRE was installed (e.g., $DEPS_DIR/0/jre)
//   - javaHome: The actual JAVA_HOME path (may be jreDir or a subdirectory)
//
// The function creates a java.sh script in profile.d that:
//  1. Exports JAVA_HOME using $DEPS_DIR runtime variable
//  2. Exports JRE_HOME (same as JAVA_HOME)
//  3. Prepends $JAVA_HOME/bin to PATH
//
// It also sets these environment variables during staging for use by frameworks.
func WriteJavaHomeProfileD(ctx *Context, jreDir, javaHome string) error {
	// Compute relative path from jreDir to javaHome
	relPath, err := filepath.Rel(jreDir, javaHome)
	if err != nil {
		return fmt.Errorf("failed to compute relative path: %w", err)
	}

	// Build the JAVA_HOME path using $DEPS_DIR environment variable
	// This allows the path to work at runtime when the app is staged
	var javaHomePath string
	if relPath == "." {
		// JAVA_HOME is directly at jreDir
		javaHomePath = "$DEPS_DIR/0/jre"
	} else {
		// JAVA_HOME is in a subdirectory (e.g., jdk-17.0.13)
		javaHomePath = fmt.Sprintf("$DEPS_DIR/0/jre/%s", relPath)
	}

	// Create the profile.d script content with JAVA_HOME, JRE_HOME, and PATH
	// Following the pattern from reference buildpacks (Ruby, Python, Go)
	envContent := fmt.Sprintf(`export JAVA_HOME=%s
export JRE_HOME=%s
export PATH=$JAVA_HOME/bin:$PATH
`, javaHomePath, javaHomePath)

	// Write the profile.d script using libbuildpack API
	if err := ctx.Stager.WriteProfileD("java.sh", envContent); err != nil {
		return fmt.Errorf("failed to write profile.d script: %w", err)
	}

	// Also set environment variables for staging time (used by frameworks during finalize)
	if err := os.Setenv("JAVA_HOME", javaHome); err != nil {
		ctx.Log.Warning("Failed to set JAVA_HOME environment variable: %s", err.Error())
	}
	if err := os.Setenv("JRE_HOME", javaHome); err != nil {
		ctx.Log.Warning("Failed to set JRE_HOME environment variable: %s", err.Error())
	}
	if err := os.Setenv("PATH", filepath.Join(javaHome, "bin")+":"+os.Getenv("PATH")); err != nil {
		ctx.Log.Warning("Failed to set PATH environment variable: %s", err.Error())
	}

	return nil
}

// containsString checks if a string contains a substring (case-insensitive)
func containsString(s, substr string) bool {
	return strings.Contains(strings.ToLower(s), strings.ToLower(substr))
}
