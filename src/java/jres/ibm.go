package jres

import (
	"fmt"
	"os"
	"path/filepath"
)

// IBMJRE implements the JRE interface for IBM JRE
// IBM JRE requires a user-provided repository via JBP_CONFIG_IBM_JRE environment variable
// IBM JRE adds specific JVM options: -Xtune:virtualized -Xshareclasses:none
type IBMJRE struct {
	ctx              *Context
	jreDir           string
	version          string
	javaHome         string
	memoryCalc       *MemoryCalculator
	jvmkill          *JVMKillAgent
	installedVersion string
}

// NewIBMJRE creates a new IBM JRE provider
func NewIBMJRE(ctx *Context) *IBMJRE {
	jreDir := filepath.Join(ctx.Stager.DepDir(), "jre")

	return &IBMJRE{
		ctx:    ctx,
		jreDir: jreDir,
	}
}

// Name returns the name of this JRE provider
func (i *IBMJRE) Name() string {
	return "IBM JRE"
}

// Detect returns true if IBM JRE should be used
// IBM JRE requires explicit configuration via JBP_CONFIG_COMPONENTS or JBP_CONFIG_IBM_JRE
func (i *IBMJRE) Detect() (bool, error) {
	// Check if explicitly configured via environment
	// Format: JBP_CONFIG_COMPONENTS='{jres: ["JavaBuildpack::Jre::IbmJRE"]}'
	configuredJRE := os.Getenv("JBP_CONFIG_COMPONENTS")
	if configuredJRE != "" && (containsString(configuredJRE, "IbmJRE") || containsString(configuredJRE, "IBM")) {
		return true, nil
	}

	// Also check legacy config
	if DetectJREByEnv("ibm_jre") {
		return true, nil
	}

	return false, nil
}

// Supply installs the IBM JRE and its components
func (i *IBMJRE) Supply() error {
	i.ctx.Log.BeginStep("Installing IBM JRE")

	// Determine version
	dep, err := GetJREVersion(i.ctx, "ibm")
	if err != nil {
		return fmt.Errorf("failed to determine IBM JRE version from manifest: %w", err)
	}

	i.version = dep.Version
	i.ctx.Log.Info("Installing IBM JRE %s", i.version)

	// Install JRE
	if err := i.ctx.Installer.InstallDependency(dep, i.jreDir); err != nil {
		return fmt.Errorf("failed to install IBM JRE: %w", err)
	}

	// Find the actual JAVA_HOME (handle nested directories from tar extraction)
	javaHome, err := i.findJavaHome()
	if err != nil {
		return fmt.Errorf("failed to find JAVA_HOME: %w", err)
	}
	i.javaHome = javaHome
	i.installedVersion = i.version

	// Write profile.d script for runtime environment
	if err := i.writeProfileDScript(); err != nil {
		i.ctx.Log.Warning("Could not write java.sh profile.d script: %s", err.Error())
	} else {
		i.ctx.Log.Debug("Created profile.d script: java.sh")
	}

	// Determine Java major version
	javaMajorVersion, err := DetermineJavaVersion(javaHome)
	if err != nil {
		i.ctx.Log.Warning("Could not determine Java version: %s", err.Error())
		javaMajorVersion = 8 // IBM JRE default
	}
	i.ctx.Log.Info("Detected Java major version: %d", javaMajorVersion)

	// Install JVMKill agent (using IBM-specific repository if configured)
	i.jvmkill = NewJVMKillAgent(i.ctx, i.jreDir, i.version)
	if err := i.jvmkill.Supply(); err != nil {
		i.ctx.Log.Warning("Failed to install JVMKill agent: %s (continuing)", err.Error())
		// Non-fatal - continue without jvmkill
	}

	// Install Memory Calculator
	i.memoryCalc = NewMemoryCalculator(i.ctx, i.jreDir, i.version, javaMajorVersion)
	if err := i.memoryCalc.Supply(); err != nil {
		i.ctx.Log.Warning("Failed to install Memory Calculator: %s (continuing)", err.Error())
		// Non-fatal - continue without memory calculator
	}

	i.ctx.Log.Info("IBM JRE installation complete")
	return nil
}

// Finalize performs final JRE configuration
// Adds IBM-specific JVM options: -Xtune:virtualized -Xshareclasses:none
func (i *IBMJRE) Finalize() error {
	i.ctx.Log.BeginStep("Finalizing IBM JRE configuration")

	// Find the actual JAVA_HOME (needed if finalize is called on a fresh instance)
	if i.javaHome == "" {
		javaHome, err := i.findJavaHome()
		if err != nil {
			i.ctx.Log.Warning("Failed to find JAVA_HOME: %s", err.Error())
		} else {
			i.javaHome = javaHome
		}
	}

	// Determine Java major version for memory calculator
	javaMajorVersion := 8 // IBM JRE default
	if i.javaHome != "" {
		if ver, err := DetermineJavaVersion(i.javaHome); err == nil {
			javaMajorVersion = ver
		}
	}

	// Reconstruct JVMKill agent component if not already set
	if i.jvmkill == nil {
		i.jvmkill = NewJVMKillAgent(i.ctx, i.jreDir, i.version)
	}

	// Finalize JVMKill agent
	if err := i.jvmkill.Finalize(); err != nil {
		i.ctx.Log.Warning("Failed to finalize JVMKill agent: %s", err.Error())
		// Non-fatal
	}

	// Reconstruct Memory Calculator component if not already set
	if i.memoryCalc == nil {
		i.memoryCalc = NewMemoryCalculator(i.ctx, i.jreDir, i.version, javaMajorVersion)
	}

	// Finalize Memory Calculator
	if err := i.memoryCalc.Finalize(); err != nil {
		i.ctx.Log.Warning("Failed to finalize Memory Calculator: %s", err.Error())
		// Non-fatal
	}

	// Add IBM-specific JVM options
	// -Xtune:virtualized - Optimizes for virtualized environments
	// -Xshareclasses:none - Disables class data sharing (not supported in containers)
	ibmOpts := "-Xtune:virtualized -Xshareclasses:none"
	if err := WriteJavaOpts(i.ctx, ibmOpts); err != nil {
		i.ctx.Log.Warning("Failed to write IBM JVM options: %s", err.Error())
		// Non-fatal
	}

	i.ctx.Log.Info("IBM JRE finalization complete")
	return nil
}

// JavaHome returns the path to JAVA_HOME
func (i *IBMJRE) JavaHome() string {
	return i.javaHome
}

// Version returns the installed JRE version
func (i *IBMJRE) Version() string {
	return i.installedVersion
}

// findJavaHome locates the actual JAVA_HOME directory after extraction
// IBM JRE tarballs usually extract to ibm-java-* or jre subdirectories
func (i *IBMJRE) findJavaHome() (string, error) {
	entries, err := os.ReadDir(i.jreDir)
	if err != nil {
		return "", fmt.Errorf("failed to read JRE directory: %w", err)
	}

	// Look for ibm-java-* or jre subdirectory
	for _, entry := range entries {
		if entry.IsDir() {
			name := entry.Name()
			// Check for common IBM JRE directory patterns
			if (len(name) > 8 && name[:8] == "ibm-java") || name == "jre" {
				path := filepath.Join(i.jreDir, name)
				// Verify it has a bin directory with java
				if _, err := os.Stat(filepath.Join(path, "bin", "java")); err == nil {
					return path, nil
				}
			}
		}
	}

	// If no subdirectory found, check if jreDir itself is valid
	if _, err := os.Stat(filepath.Join(i.jreDir, "bin", "java")); err == nil {
		return i.jreDir, nil
	}

	return "", fmt.Errorf("could not find valid JAVA_HOME in %s", i.jreDir)
}

// writeProfileDScript creates the profile.d script for setting JAVA_HOME, JRE_HOME, and PATH at runtime
func (i *IBMJRE) writeProfileDScript() error {
	return WriteJavaHomeProfileD(i.ctx, i.jreDir, i.javaHome)
}
