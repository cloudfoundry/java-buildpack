package jres

import (
	"fmt"
	"os"
	"path/filepath"
)

// ZingJRE implements the JRE interface for Azul Platform Prime (Zing) JRE
// Zing JRE requires a user-provided repository via JBP_CONFIG_ZING_JRE environment variable
// Unlike other JREs, Zing does NOT use jvmkill or memory calculator - only adds -XX:+ExitOnOutOfMemoryError
type ZingJRE struct {
	ctx              *Context
	jreDir           string
	version          string
	javaHome         string
	installedVersion string
}

// NewZingJRE creates a new Zing JRE provider
func NewZingJRE(ctx *Context) *ZingJRE {
	jreDir := filepath.Join(ctx.Stager.DepDir(), "jre")

	return &ZingJRE{
		ctx:    ctx,
		jreDir: jreDir,
	}
}

// Name returns the name of this JRE provider
func (z *ZingJRE) Name() string {
	return "Zing JRE"
}

// Detect returns true if Zing JRE should be used
// Zing JRE requires explicit configuration via JBP_CONFIG_COMPONENTS or JBP_CONFIG_ZING_JRE
func (z *ZingJRE) Detect() (bool, error) {
	// Check if explicitly configured via environment
	// Format: JBP_CONFIG_COMPONENTS='{jres: ["JavaBuildpack::Jre::ZingJRE"]}'
	configuredJRE := os.Getenv("JBP_CONFIG_COMPONENTS")
	if configuredJRE != "" && (containsString(configuredJRE, "ZingJRE") || containsString(configuredJRE, "Zing")) {
		return true, nil
	}

	// Also check legacy config
	if DetectJREByEnv("zing_jre") {
		return true, nil
	}

	return false, nil
}

// Supply installs the Zing JRE
// Note: Zing JRE does NOT install jvmkill or memory calculator components
func (z *ZingJRE) Supply() error {
	z.ctx.Log.BeginStep("Installing Zing JRE")

	// Determine version
	dep, err := GetJREVersion(z.ctx, "zing")
	if err != nil {
		return fmt.Errorf("failed to determine Zing JRE version from manifest: %w", err)
	}

	z.version = dep.Version
	z.ctx.Log.Info("Installing Zing JRE %s", z.version)

	// Install JRE
	if err := z.ctx.Installer.InstallDependency(dep, z.jreDir); err != nil {
		return fmt.Errorf("failed to install Zing JRE: %w", err)
	}

	// Find the actual JAVA_HOME (handle nested directories from tar extraction)
	javaHome, err := z.findJavaHome()
	if err != nil {
		return fmt.Errorf("failed to find JAVA_HOME: %w", err)
	}
	z.javaHome = javaHome
	z.installedVersion = z.version

	// Write profile.d script for runtime JAVA_HOME setup
	if err := z.writeProfileDScript(); err != nil {
		z.ctx.Log.Warning("Could not write java.sh profile.d script: %s", err.Error())
	} else {
		z.ctx.Log.Debug("Created profile.d script: java.sh")
	}

	z.ctx.Log.Info("Zing JRE installation complete")
	return nil
}

// Finalize performs final JRE configuration
// Adds -XX:+ExitOnOutOfMemoryError to JAVA_OPTS
func (z *ZingJRE) Finalize() error {
	z.ctx.Log.BeginStep("Finalizing Zing JRE configuration")

	// Find the actual JAVA_HOME (needed if finalize is called on a fresh instance)
	if z.javaHome == "" {
		javaHome, err := z.findJavaHome()
		if err != nil {
			z.ctx.Log.Warning("Failed to find JAVA_HOME: %s", err.Error())
		} else {
			z.javaHome = javaHome
		}
	}

	// Add Zing-specific JVM option for OOM handling
	// Unlike other JREs, Zing uses built-in -XX:+ExitOnOutOfMemoryError instead of jvmkill
	if err := WriteJavaOpts(z.ctx, "-XX:+ExitOnOutOfMemoryError"); err != nil {
		z.ctx.Log.Warning("Failed to write JAVA_OPTS: %s", err.Error())
		// Non-fatal
	}

	z.ctx.Log.Info("Zing JRE finalization complete")
	return nil
}

// JavaHome returns the path to JAVA_HOME
func (z *ZingJRE) JavaHome() string {
	return z.javaHome
}

// Version returns the installed JRE version
func (z *ZingJRE) Version() string {
	return z.installedVersion
}

// findJavaHome locates the actual JAVA_HOME directory after extraction
// Zing JRE tarballs usually extract to zing* subdirectories
func (z *ZingJRE) findJavaHome() (string, error) {
	entries, err := os.ReadDir(z.jreDir)
	if err != nil {
		return "", fmt.Errorf("failed to read JRE directory: %w", err)
	}

	// Look for zing* subdirectory
	for _, entry := range entries {
		if entry.IsDir() {
			name := entry.Name()
			// Check for common Zing JRE directory patterns
			if len(name) >= 4 && name[:4] == "zing" {
				path := filepath.Join(z.jreDir, name)
				// Verify it has a bin directory with java
				if _, err := os.Stat(filepath.Join(path, "bin", "java")); err == nil {
					return path, nil
				}
			}
		}
	}

	// If no subdirectory found, check if jreDir itself is valid
	if _, err := os.Stat(filepath.Join(z.jreDir, "bin", "java")); err == nil {
		return z.jreDir, nil
	}

	return "", fmt.Errorf("could not find valid JAVA_HOME in %s", z.jreDir)
}

// writeProfileDScript creates the java.sh profile.d script
// This script sets JAVA_HOME, JRE_HOME, and updates PATH at application runtime
func (z *ZingJRE) writeProfileDScript() error {
	// Compute relative path from jreDir to javaHome
	relPath, err := filepath.Rel(z.jreDir, z.javaHome)
	if err != nil {
		return fmt.Errorf("failed to compute relative path: %w", err)
	}

	// Build the runtime JAVA_HOME path
	// At runtime, DEPS_DIR will point to the app's dependency directory
	javaHomePath := filepath.Join("$DEPS_DIR", "0", "jre", relPath)

	// Create the environment script content
	envContent := fmt.Sprintf(`export JAVA_HOME=%s
export JRE_HOME=$JAVA_HOME
export PATH=$JAVA_HOME/bin:$PATH
`, javaHomePath)

	// Write the profile.d script using libbuildpack API
	if err := z.ctx.Stager.WriteProfileD("java.sh", envContent); err != nil {
		return fmt.Errorf("failed to write profile.d script: %w", err)
	}

	// Also set environment for the staging process
	os.Setenv("JAVA_HOME", z.javaHome)
	os.Setenv("JRE_HOME", z.javaHome)
	os.Setenv("PATH", fmt.Sprintf("%s/bin:%s", z.javaHome, os.Getenv("PATH")))

	return nil
}
