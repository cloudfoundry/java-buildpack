package jres

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/libbuildpack"
)

// Default JRE provider
// Change this value to set which JRE is used by default when no JRE is explicitly configured
// Valid values: "openjdk", "zulu", "sapmachine", "graalvm", "oracle", "ibm", "zing"
const DefaultJREProvider = "openjdk"

// Memory calculator constants
const (
	DefaultStackThreads = 250
	DefaultHeadroom     = 0
	DefaultClassCount   = 18000 // Default class count when counting fails (after 35% factor: ~6300)
	Java9ClassCount     = 42215 // Classes in Java 9+ JRE
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

	// MemoryCalculatorCommand returns the shell command snippet to run memory calculator
	// This command is prepended to the container startup command
	// Returns empty string if memory calculator is not installed
	MemoryCalculatorCommand() string
}

// Registry manages multiple JRE providers
type Registry struct {
	ctx        *common.Context
	providers  []JRE
	defaultJRE JRE
}

// NewRegistry creates a new JRE registry
func NewRegistry(ctx *common.Context) *Registry {
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

// RegisterStandardJREs registers all standard JRE providers in the correct priority order.
// This ensures Supply and Finalize phases use the same detection order.
// The default JRE is determined by the DefaultJREProvider constant.
func (r *Registry) RegisterStandardJREs() {
	// Create all JRE providers
	jreProviders := map[string]JRE{
		"openjdk":    NewOpenJDKJRE(r.ctx),
		"zulu":       NewZuluJRE(r.ctx),
		"sapmachine": NewSapMachineJRE(r.ctx),
		"graalvm":    NewGraalVMJRE(r.ctx),
		"oracle":     NewOracleJRE(r.ctx),
		"ibm":        NewIBMJRE(r.ctx),
		"zing":       NewZingJRE(r.ctx),
	}

	// Set the default JRE based on the constant
	defaultJRE, exists := jreProviders[DefaultJREProvider]
	if !exists {
		r.ctx.Log.Warning("Invalid DefaultJREProvider '%s', falling back to openjdk", DefaultJREProvider)
		defaultJRE = jreProviders["openjdk"]
	}
	r.SetDefault(defaultJRE)

	// Register all JREs
	for _, jre := range jreProviders {
		r.Register(jre)
	}
}

// Get returns the JRE whose Name() matches the given name, or nil if not found.
// Used by the finalize phase to resolve a JRE by the name stored in config.yml.
func (r *Registry) Get(name string) JRE {
	for _, jre := range r.providers {
		if jre.Name() == name {
			return jre
		}
	}
	return nil
}

// Detect finds the JRE provider that should be used
// If a JRE is explicitly configured, it uses that JRE and fails if detection errors
// If no JRE is explicitly configured, it uses the configured default JRE
// Returns the JRE, its name, and any error
func (r *Registry) Detect() (JRE, string, error) {
	var detectionErrors []error

	// Check for deprecated JBP_CONFIG_COMPONENTS usage
	if componentsEnv := os.Getenv("JBP_CONFIG_COMPONENTS"); componentsEnv != "" {
		r.ctx.Log.Warning("JBP_CONFIG_COMPONENTS is deprecated for JRE selection and will be ignored")
		r.ctx.Log.Warning("Use JRE-specific environment variables instead:")
		r.ctx.Log.Warning("  - JBP_CONFIG_OPEN_JDK_JRE for OpenJDK")
		r.ctx.Log.Warning("  - JBP_CONFIG_SAP_MACHINE_JRE for SapMachine")
		r.ctx.Log.Warning("  - JBP_CONFIG_ZULU_JRE for Zulu")
		r.ctx.Log.Warning("  - JBP_CONFIG_GRAAL_VM_JRE for GraalVM")
		r.ctx.Log.Warning("  - JBP_CONFIG_IBM_JRE for IBM Semeru")
		r.ctx.Log.Warning("  - JBP_CONFIG_ORACLE_JRE for Oracle")
		r.ctx.Log.Warning("  - JBP_CONFIG_ZING_JRE for Azul Platform Prime")
	}

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

	// No JRE found and no default configured - this is an error condition
	// A Java application cannot run without a JRE
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
	Ctx         *common.Context
	JREDir      string
	JREVersion  string
	ComponentID string
}

// Helper functions

// DetectJREByEnv checks environment variables for JRE selection
// Takes the internal JRE name (e.g., "sapmachine", "openjdk", "zulu")
// Checks both auto-generated and documented environment variable names
// This matches the behavior of GetJREVersion
func DetectJREByEnv(jreName string) bool {
	// Check auto-generated name pattern (e.g., JBP_CONFIG_SAPMACHINE)
	envKey := fmt.Sprintf("JBP_CONFIG_%s", strings.ToUpper(strings.ReplaceAll(jreName, "-", "_")))
	if os.Getenv(envKey) != "" {
		return true
	}

	// Check documented environment variable name from map
	// This ensures backward compatibility with documented JBP_CONFIG_*_JRE convention
	if documentedEnvKey, exists := jreNameToDocumentedEnvVar[jreName]; exists {
		if os.Getenv(documentedEnvKey) != "" {
			return true
		}
	}

	return false
}

// jreNameToDocumentedEnvVar maps JRE names to their documented environment variable names
// This maintains backward compatibility with the documented JBP_CONFIG_*_JRE convention
var jreNameToDocumentedEnvVar = map[string]string{
	"openjdk":    "JBP_CONFIG_OPEN_JDK_JRE",
	"sapmachine": "JBP_CONFIG_SAP_MACHINE_JRE",
	"zulu":       "JBP_CONFIG_ZULU_JRE",
	"graalvm":    "JBP_CONFIG_GRAAL_VM_JRE",
	"ibm":        "JBP_CONFIG_IBM_JRE",
	"oracle":     "JBP_CONFIG_ORACLE_JRE",
	"zing":       "JBP_CONFIG_ZING_JRE",
}

// GetJREVersion gets the desired JRE version from environment or uses default
// Supports BP_JAVA_VERSION (simple version) and JBP_CONFIG_<JRE_NAME> (complex config)
func GetJREVersion(ctx *common.Context, jreName string) (libbuildpack.Dependency, error) {
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

	// Check for JBP_CONFIG_<JRE_NAME> environment variable
	// Try both the auto-generated name and the documented name for backward compatibility
	envKey := fmt.Sprintf("JBP_CONFIG_%s", strings.ToUpper(strings.ReplaceAll(jreName, "-", "_")))
	envVal := os.Getenv(envKey)

	// If not found, check for documented environment variable name (e.g., JBP_CONFIG_OPEN_JDK_JRE)
	// This ensures backward compatibility with documented naming conventions
	if envVal == "" {
		if documentedEnvKey, exists := jreNameToDocumentedEnvVar[jreName]; exists {
			envVal = os.Getenv(documentedEnvKey)
			if envVal != "" {
				envKey = documentedEnvKey
			}
		}
	}

	if envVal != "" {
		ctx.Log.Debug("Found %s='%s'", envKey, envVal)

		versionPattern := parseJBPConfigVersion(envVal)
		if versionPattern == "" {
			// No version specified — env var is used for other settings (e.g. memory_calculator).
			// Fall back to manifest default.
			ctx.Log.Debug("%s set but contains no version field, using manifest default", envKey)
		} else {
			ctx.Log.Debug("Parsed version pattern from %s: '%s'", envKey, versionPattern)

			normalizedPattern := normalizeVersionPattern(versionPattern)
			ctx.Log.Debug("Normalized pattern: '%s' -> '%s'", versionPattern, normalizedPattern)

			availableVersions := ctx.Manifest.AllDependencyVersions(jreName)
			if len(availableVersions) == 0 {
				return libbuildpack.Dependency{}, fmt.Errorf("no versions of %s found in manifest", jreName)
			}
			ctx.Log.Debug("Available versions for %s: %v", jreName, availableVersions)

			matchedVersion, err := libbuildpack.FindMatchingVersion(normalizedPattern, availableVersions)
			if err != nil {
				ctx.Log.Debug("FindMatchingVersion failed: %s", err.Error())
				return libbuildpack.Dependency{}, fmt.Errorf("no version of %s matching '%s' found in manifest. Available versions: %v", jreName, versionPattern, availableVersions)
			}
			ctx.Log.Debug("Matched version: %s", matchedVersion)

			return libbuildpack.Dependency{Name: jreName, Version: matchedVersion}, nil
		}
	}

	// Get default version from manifest (no version constraint)
	dep, err := ctx.Manifest.DefaultVersion(jreName)
	if err != nil {
		return libbuildpack.Dependency{}, err
	}

	return dep, nil
}

func normalizeVersionPattern(version string) string {
	if strings.Contains(version, "+") {
		return strings.ReplaceAll(version, "+", "*")
	}
	if strings.Contains(version, "*") {
		return version
	}
	return version + ".*"
}

func parseJBPConfigVersion(configValue string) string {
	re := regexp.MustCompile(`version:\s*['"]?([0-9]+[0-9.*+]*)['"]?`)
	matches := re.FindStringSubmatch(configValue)
	if len(matches) >= 2 {
		return strings.TrimSpace(matches[1])
	}
	return ""
}

// WriteJavaOpts writes JAVA_OPTS to a .opts file for centralized assembly
// JRE components use priority 05 to run early (before frameworks)
func WriteJavaOpts(ctx *common.Context, opts string) error {
	return WriteJavaOptsWithPriority(ctx, 05, "jre", opts)
}

// WriteJavaOptsWithPriority writes JAVA_OPTS to a numbered .opts file for centralized assembly
// Priority determines execution order (lower numbers run first)
// Multiple calls with the same priority/name will append to the same file
func WriteJavaOptsWithPriority(ctx *common.Context, priority int, name string, opts string) error {
	// Create java_opts directory in deps
	optsDir := filepath.Join(ctx.Stager.DepDir(), "java_opts")
	if err := os.MkdirAll(optsDir, 0755); err != nil {
		return fmt.Errorf("failed to create java_opts directory: %w", err)
	}

	// Write .opts file with priority prefix (e.g., 05_jre.opts)
	filename := fmt.Sprintf("%02d_%s.opts", priority, name)
	optsFile := filepath.Join(optsDir, filename)

	// Append to existing content if file exists
	var content string
	if existing, err := os.ReadFile(optsFile); err == nil {
		content = strings.TrimSpace(string(existing)) + " " + opts
	} else {
		content = opts
	}

	if err := os.WriteFile(optsFile, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write %s: %w", filename, err)
	}

	ctx.Log.Debug("Wrote JAVA_OPTS to %s (priority %d)", filename, priority)
	return nil
}

// WriteJavaHomeProfileD creates a profile.d script that exports JAVA_HOME, JRE_HOME, and PATH at runtime
// This is needed for containers that use startup scripts expecting $JAVA_HOME environment variable
//
// Parameters:
//   - ctx: JRE context with Stager and Logger
//   - jreDir: The directory where the JRE was installed (e.g., $DEPS_DIR/<idx>/jre)
//   - javaHome: The actual JAVA_HOME path (may be jreDir or a subdirectory)
//
// The function creates a java.sh script in profile.d that:
//  1. Exports JAVA_HOME using $DEPS_DIR runtime variable
//  2. Exports JRE_HOME (same as JAVA_HOME)
//  3. Prepends $JAVA_HOME/bin to PATH
//
// It also sets these environment variables during staging for use by frameworks.
func WriteJavaHomeProfileD(ctx *common.Context, jreDir, javaHome string) error {
	// Compute relative path from jreDir to javaHome
	relPath, err := filepath.Rel(jreDir, javaHome)
	if err != nil {
		return fmt.Errorf("failed to compute relative path: %w", err)
	}

	// Build the JAVA_HOME path using $DEPS_DIR environment variable
	// This allows the path to work at runtime when the app is staged
	// Use the actual buildpack index from ctx.Stager.DepsIdx() to support multi-buildpack scenarios
	depsIdx := ctx.Stager.DepsIdx()
	var javaHomePath string
	if relPath == "." {
		// JAVA_HOME is directly at jreDir
		javaHomePath = fmt.Sprintf("$DEPS_DIR/%s/jre", depsIdx)
	} else {
		// JAVA_HOME is in a subdirectory (e.g., jdk-17.0.13)
		javaHomePath = fmt.Sprintf("$DEPS_DIR/%s/jre/%s", depsIdx, relPath)
	}

	// Create the profile.d script content with JAVA_HOME, JRE_HOME, and PATH
	// Create the profile.d script content with JAVA_HOME, JRE_HOME, and PATH
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
