package jres

import (
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"os"
	"path/filepath"
)

// ZuluJRE implements the JRE interface for Azul Zulu OpenJDK
type ZuluJRE struct {
	ctx              *common.Context
	jreDir           string
	version          string
	javaHome         string
	memoryCalc       *MemoryCalculator
	jvmkill          *JVMKillAgent
	installedVersion string
}

// NewZuluJRE creates a new Zulu JRE provider
func NewZuluJRE(ctx *common.Context) *ZuluJRE {
	jreDir := filepath.Join(ctx.Stager.DepDir(), "jre")

	return &ZuluJRE{
		ctx:    ctx,
		jreDir: jreDir,
	}
}

// Name returns the name of this JRE provider
func (z *ZuluJRE) Name() string {
	return "Zulu"
}

// Detect returns true if Zulu JRE should be used
// Zulu is selected via JBP_CONFIG_ZULU_JRE environment variable
func (z *ZuluJRE) Detect() (bool, error) {
	return DetectJREByEnv("zulu"), nil
}

// Supply installs the Zulu JRE and its components
func (z *ZuluJRE) Supply() error {
	z.ctx.Log.BeginStep("Installing Zulu JRE")

	// Determine version
	dep, err := GetJREVersion(z.ctx, "zulu")
	if err != nil {
		return fmt.Errorf("failed to determine Zulu version from manifest: %w", err)
	}

	z.version = dep.Version
	z.ctx.Log.Info("Installing Zulu %s", z.version)

	// Install JRE
	if err := z.ctx.Installer.InstallDependency(dep, z.jreDir); err != nil {
		return fmt.Errorf("failed to install Zulu: %w", err)
	}

	// Find the actual JAVA_HOME (handle nested directories from tar extraction)
	javaHome, err := z.findJavaHome()
	if err != nil {
		return fmt.Errorf("failed to find JAVA_HOME: %w", err)
	}
	z.javaHome = javaHome
	z.installedVersion = z.version

	// Set up JAVA_HOME environment
	if err := z.writeProfileDScript(); err != nil {
		z.ctx.Log.Warning("Could not write java.sh profile.d script: %s", err.Error())
	} else {
		z.ctx.Log.Debug("Created profile.d script: java.sh")
	}

	// Determine Java major version
	javaMajorVersion, err := common.DetermineJavaVersion(javaHome)
	if err != nil {
		z.ctx.Log.Warning("Could not determine Java version: %s", err.Error())
		javaMajorVersion = 11 // default for Zulu
	}
	z.ctx.Log.Info("Detected Java major version: %d", javaMajorVersion)

	// Install JVMKill agent
	z.jvmkill = NewJVMKillAgent(z.ctx, z.jreDir, z.version)
	if err := z.jvmkill.Supply(); err != nil {
		z.ctx.Log.Warning("Failed to install JVMKill agent: %s (continuing)", err.Error())
		// Non-fatal - continue without jvmkill
	}

	// Install Memory Calculator
	z.memoryCalc = NewMemoryCalculator(z.ctx, z.jreDir, z.version, javaMajorVersion)
	if err := z.memoryCalc.Supply(); err != nil {
		z.ctx.Log.Warning("Failed to install Memory Calculator: %s (continuing)", err.Error())
		// Non-fatal - continue without memory calculator
	}

	z.ctx.Log.Info("Zulu JRE installation complete")
	return nil
}

// Finalize performs final JRE configuration
func (z *ZuluJRE) Finalize() error {
	z.ctx.Log.BeginStep("Finalizing Zulu JRE configuration")

	// Find the actual JAVA_HOME (needed if finalize is called on a fresh instance)
	if z.javaHome == "" {
		javaHome, err := z.findJavaHome()
		if err != nil {
			z.ctx.Log.Warning("Failed to find JAVA_HOME: %s", err.Error())
		} else {
			z.javaHome = javaHome
		}
	}

	// Set JAVA_HOME in environment for frameworks that need it during finalize phase
	// (e.g., Luna Security Provider, Container Security Provider)
	if z.javaHome != "" {
		if err := os.Setenv("JAVA_HOME", z.javaHome); err != nil {
			z.ctx.Log.Warning("Failed to set JAVA_HOME environment variable: %s", err.Error())
		} else {
			z.ctx.Log.Debug("Set JAVA_HOME=%s", z.javaHome)
		}
	}

	// Determine Java major version for memory calculator
	javaMajorVersion := 11 // default
	if z.javaHome != "" {
		if ver, err := common.DetermineJavaVersion(z.javaHome); err == nil {
			javaMajorVersion = ver
		}
	}

	// Reconstruct JVMKill agent component if not already set
	if z.jvmkill == nil {
		z.jvmkill = NewJVMKillAgent(z.ctx, z.jreDir, z.version)
	}

	// Finalize JVMKill agent
	if err := z.jvmkill.Finalize(); err != nil {
		z.ctx.Log.Warning("Failed to finalize JVMKill agent: %s", err.Error())
		// Non-fatal
	}

	// Reconstruct Memory Calculator component if not already set
	if z.memoryCalc == nil {
		z.memoryCalc = NewMemoryCalculator(z.ctx, z.jreDir, z.version, javaMajorVersion)
	}

	// Finalize Memory Calculator
	if err := z.memoryCalc.Finalize(); err != nil {
		z.ctx.Log.Warning("Failed to finalize Memory Calculator: %s", err.Error())
		// Non-fatal
	}

	z.ctx.Log.Info("Zulu JRE finalization complete")
	return nil
}

// JavaHome returns the path to JAVA_HOME
func (z *ZuluJRE) JavaHome() string {
	return z.javaHome
}

// Version returns the installed JRE version
func (z *ZuluJRE) Version() string {
	return z.installedVersion
}

// MemoryCalculatorCommand returns the shell command snippet to run memory calculator at runtime
func (z *ZuluJRE) MemoryCalculatorCommand() string {
	if z.memoryCalc == nil {
		return ""
	}
	return z.memoryCalc.GetCalculatorCommand()
}

// findJavaHome locates the actual JAVA_HOME directory after extraction
// Zulu tarballs usually extract to zulu-* subdirectories
func (z *ZuluJRE) findJavaHome() (string, error) {
	entries, err := os.ReadDir(z.jreDir)
	if err != nil {
		return "", fmt.Errorf("failed to read JRE directory: %w", err)
	}

	// Look for zulu-*, jdk-*, or jre-* subdirectory
	for _, entry := range entries {
		if entry.IsDir() {
			name := entry.Name()
			// Check for common Zulu directory patterns
			if len(name) > 4 && name[:4] == "zulu" {
				path := filepath.Join(z.jreDir, name)
				// Verify it has a bin directory with java
				if _, err := os.Stat(filepath.Join(path, "bin", "java")); err == nil {
					return path, nil
				}
			}
			// Also check for standard jdk/jre patterns
			if len(name) > 3 && (name[:3] == "jdk" || name[:3] == "jre") {
				path := filepath.Join(z.jreDir, name)
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

// writeProfileDScript creates a profile.d script that exports JAVA_HOME, JRE_HOME, and PATH at runtime
// Delegates to the shared helper function in jre.go
func (z *ZuluJRE) writeProfileDScript() error {
	return WriteJavaHomeProfileD(z.ctx, z.jreDir, z.javaHome)
}
