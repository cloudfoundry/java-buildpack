package jres

import (
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"os"
	"path/filepath"
)

// OracleJRE implements the JRE interface for Oracle JRE
// Oracle JRE requires a user-provided repository via JBP_CONFIG_ORACLE_JRE environment variable
type OracleJRE struct {
	ctx              *common.Context
	jreDir           string
	version          string
	javaHome         string
	memoryCalc       *MemoryCalculator
	jvmkill          *JVMKillAgent
	installedVersion string
}

// NewOracleJRE creates a new Oracle JRE provider
func NewOracleJRE(ctx *common.Context) *OracleJRE {
	jreDir := filepath.Join(ctx.Stager.DepDir(), "jre")

	return &OracleJRE{
		ctx:    ctx,
		jreDir: jreDir,
	}
}

// Name returns the name of this JRE provider
func (o *OracleJRE) Name() string {
	return "Oracle JRE"
}

// Detect returns true if Oracle JRE should be used
// Oracle JRE requires explicit configuration via JBP_CONFIG_ORACLE_JRE environment variable
func (o *OracleJRE) Detect() (bool, error) {
	return DetectJREByEnv("oracle"), nil
}

// Supply installs the Oracle JRE and its components
func (o *OracleJRE) Supply() error {
	o.ctx.Log.BeginStep("Installing Oracle JRE")

	// Determine version
	dep, err := GetJREVersion(o.ctx, "oracle")
	if err != nil {
		return fmt.Errorf("failed to determine Oracle JRE version from manifest: %w", err)
	}

	o.version = dep.Version
	o.ctx.Log.Info("Installing Oracle JRE %s", o.version)

	// Install JRE
	if err := o.ctx.Installer.InstallDependency(dep, o.jreDir); err != nil {
		return fmt.Errorf("failed to install Oracle JRE: %w", err)
	}

	// Find the actual JAVA_HOME (handle nested directories from tar extraction)
	javaHome, err := o.findJavaHome()
	if err != nil {
		return fmt.Errorf("failed to find JAVA_HOME: %w", err)
	}
	o.javaHome = javaHome
	o.installedVersion = o.version

	// Write profile.d script for runtime environment
	if err := o.writeProfileDScript(); err != nil {
		o.ctx.Log.Warning("Could not write java.sh profile.d script: %s", err.Error())
	} else {
		o.ctx.Log.Debug("Created profile.d script: java.sh")
	}

	// Determine Java major version
	javaMajorVersion, err := common.DetermineJavaVersion(javaHome)
	if err != nil {
		o.ctx.Log.Warning("Could not determine Java version: %s", err.Error())
		javaMajorVersion = 17 // default
	}
	o.ctx.Log.Info("Detected Java major version: %d", javaMajorVersion)

	// Install JVMKill agent
	o.jvmkill = NewJVMKillAgent(o.ctx, o.jreDir, o.version)
	if err := o.jvmkill.Supply(); err != nil {
		o.ctx.Log.Warning("Failed to install JVMKill agent: %s (continuing)", err.Error())
		// Non-fatal - continue without jvmkill
	}

	// Install Memory Calculator
	o.memoryCalc = NewMemoryCalculator(o.ctx, o.jreDir, o.version, javaMajorVersion)
	if err := o.memoryCalc.Supply(); err != nil {
		o.ctx.Log.Warning("Failed to install Memory Calculator: %s (continuing)", err.Error())
		// Non-fatal - continue without memory calculator
	}

	o.ctx.Log.Info("Oracle JRE installation complete")
	return nil
}

// Finalize performs final JRE configuration
func (o *OracleJRE) Finalize() error {
	o.ctx.Log.BeginStep("Finalizing Oracle JRE configuration")

	// Find the actual JAVA_HOME (needed if finalize is called on a fresh instance)
	if o.javaHome == "" {
		javaHome, err := o.findJavaHome()
		if err != nil {
			o.ctx.Log.Warning("Failed to find JAVA_HOME: %s", err.Error())
		} else {
			o.javaHome = javaHome
		}
	}

	// Set JAVA_HOME in environment for frameworks that need it during finalize phase
	// (e.g., Luna Security Provider, Container Security Provider)
	if o.javaHome != "" {
		if err := os.Setenv("JAVA_HOME", o.javaHome); err != nil {
			o.ctx.Log.Warning("Failed to set JAVA_HOME environment variable: %s", err.Error())
		} else {
			o.ctx.Log.Debug("Set JAVA_HOME=%s", o.javaHome)
		}
	}

	// Determine Java major version for memory calculator
	javaMajorVersion := 17 // default
	if o.javaHome != "" {
		if ver, err := common.DetermineJavaVersion(o.javaHome); err == nil {
			javaMajorVersion = ver
		}
	}

	// Reconstruct JVMKill agent component if not already set
	if o.jvmkill == nil {
		o.jvmkill = NewJVMKillAgent(o.ctx, o.jreDir, o.version)
	}

	// Finalize JVMKill agent
	if err := o.jvmkill.Finalize(); err != nil {
		o.ctx.Log.Warning("Failed to finalize JVMKill agent: %s", err.Error())
		// Non-fatal
	}

	// Reconstruct Memory Calculator component if not already set
	if o.memoryCalc == nil {
		o.memoryCalc = NewMemoryCalculator(o.ctx, o.jreDir, o.version, javaMajorVersion)
	}

	// Finalize Memory Calculator
	if err := o.memoryCalc.Finalize(); err != nil {
		o.ctx.Log.Warning("Failed to finalize Memory Calculator: %s", err.Error())
		// Non-fatal
	}

	o.ctx.Log.Info("Oracle JRE finalization complete")
	return nil
}

// JavaHome returns the path to JAVA_HOME
func (o *OracleJRE) JavaHome() string {
	return o.javaHome
}

// Version returns the installed JRE version
func (o *OracleJRE) Version() string {
	return o.installedVersion
}

// MemoryCalculatorCommand returns the shell command snippet to run memory calculator at runtime
func (o *OracleJRE) MemoryCalculatorCommand() string {
	if o.memoryCalc == nil {
		return ""
	}
	return o.memoryCalc.GetCalculatorCommand()
}

// findJavaHome locates the actual JAVA_HOME directory after extraction
// Oracle JRE tarballs usually extract to jdk-* or jre-* subdirectories
func (o *OracleJRE) findJavaHome() (string, error) {
	entries, err := os.ReadDir(o.jreDir)
	if err != nil {
		return "", fmt.Errorf("failed to read JRE directory: %w", err)
	}

	// Look for jdk-* or jre-* subdirectory
	for _, entry := range entries {
		if entry.IsDir() {
			name := entry.Name()
			// Check for common Oracle JRE directory patterns
			if len(name) > 3 && (name[:3] == "jdk" || name[:3] == "jre") {
				path := filepath.Join(o.jreDir, name)
				// Verify it has a bin directory with java
				if _, err := os.Stat(filepath.Join(path, "bin", "java")); err == nil {
					return path, nil
				}
			}
		}
	}

	// If no subdirectory found, check if jreDir itself is valid
	if _, err := os.Stat(filepath.Join(o.jreDir, "bin", "java")); err == nil {
		return o.jreDir, nil
	}

	return "", fmt.Errorf("could not find valid JAVA_HOME in %s", o.jreDir)
}

// writeProfileDScript creates the profile.d script for setting JAVA_HOME, JRE_HOME, and PATH at runtime
func (o *OracleJRE) writeProfileDScript() error {
	return WriteJavaHomeProfileD(o.ctx, o.jreDir, o.javaHome)
}
