package jres

import (
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"os"
	"path/filepath"
)

// GraalVMJRE implements the JRE interface for GraalVM
type GraalVMJRE struct {
	ctx              *common.Context
	jreDir           string
	version          string
	javaHome         string
	memoryCalc       *MemoryCalculator
	jvmkill          *JVMKillAgent
	installedVersion string
}

// NewGraalVMJRE creates a new GraalVM JRE provider
func NewGraalVMJRE(ctx *common.Context) *GraalVMJRE {
	jreDir := filepath.Join(ctx.Stager.DepDir(), "jre")

	return &GraalVMJRE{
		ctx:    ctx,
		jreDir: jreDir,
	}
}

// Name returns the name of this JRE provider
func (g *GraalVMJRE) Name() string {
	return "GraalVM"
}

// Detect returns true if GraalVM JRE should be used
// GraalVM is selected via JBP_CONFIG_GRAAL_VM_JRE environment variable
func (g *GraalVMJRE) Detect() (bool, error) {
	return DetectJREByEnv("graalvm"), nil
}

// Supply installs the GraalVM JRE and its components
func (g *GraalVMJRE) Supply() error {
	g.ctx.Log.BeginStep("Installing GraalVM JRE")

	// Determine version
	dep, err := GetJREVersion(g.ctx, "graalvm")
	if err != nil {
		return fmt.Errorf("failed to determine GraalVM version from manifest: %w", err)
	}

	g.version = dep.Version
	g.ctx.Log.Info("Installing GraalVM %s", g.version)

	// Install JRE
	if err := g.ctx.Installer.InstallDependency(dep, g.jreDir); err != nil {
		return fmt.Errorf("failed to install GraalVM: %w (ensure repository_root is configured)", err)
	}

	// Find the actual JAVA_HOME (handle nested directories from tar extraction)
	javaHome, err := g.findJavaHome()
	if err != nil {
		return fmt.Errorf("failed to find JAVA_HOME: %w", err)
	}
	g.javaHome = javaHome
	g.installedVersion = g.version

	// Write profile.d script for runtime environment
	if err := g.writeProfileDScript(); err != nil {
		g.ctx.Log.Warning("Could not write java.sh profile.d script: %s", err.Error())
	} else {
		g.ctx.Log.Debug("Created profile.d script: java.sh")
	}

	// Determine Java major version
	javaMajorVersion, err := common.DetermineJavaVersion(javaHome)
	if err != nil {
		g.ctx.Log.Warning("Could not determine Java version: %s", err.Error())
		javaMajorVersion = 17 // default for GraalVM
	}
	g.ctx.Log.Info("Detected Java major version: %d", javaMajorVersion)

	// Install JVMKill agent
	g.jvmkill = NewJVMKillAgent(g.ctx, g.jreDir, g.version)
	if err := g.jvmkill.Supply(); err != nil {
		g.ctx.Log.Warning("Failed to install JVMKill agent: %s (continuing)", err.Error())
		// Non-fatal - continue without jvmkill
	}

	// Install Memory Calculator
	g.memoryCalc = NewMemoryCalculator(g.ctx, g.jreDir, g.version, javaMajorVersion)
	if err := g.memoryCalc.Supply(); err != nil {
		g.ctx.Log.Warning("Failed to install Memory Calculator: %s (continuing)", err.Error())
		// Non-fatal - continue without memory calculator
	}

	g.ctx.Log.Info("GraalVM JRE installation complete")
	return nil
}

// Finalize performs final JRE configuration
func (g *GraalVMJRE) Finalize() error {
	g.ctx.Log.BeginStep("Finalizing GraalVM JRE configuration")

	// Find the actual JAVA_HOME (needed if finalize is called on a fresh instance)
	if g.javaHome == "" {
		javaHome, err := g.findJavaHome()
		if err != nil {
			g.ctx.Log.Warning("Failed to find JAVA_HOME: %s", err.Error())
		} else {
			g.javaHome = javaHome
		}
	}

	// Set JAVA_HOME in environment for frameworks that need it during finalize phase
	// (e.g., Luna Security Provider, Container Security Provider)
	if g.javaHome != "" {
		if err := os.Setenv("JAVA_HOME", g.javaHome); err != nil {
			g.ctx.Log.Warning("Failed to set JAVA_HOME environment variable: %s", err.Error())
		} else {
			g.ctx.Log.Debug("Set JAVA_HOME=%s", g.javaHome)
		}
	}

	// Determine Java major version for memory calculator
	javaMajorVersion := 17 // default
	if g.javaHome != "" {
		if ver, err := common.DetermineJavaVersion(g.javaHome); err == nil {
			javaMajorVersion = ver
		}
	}

	// Reconstruct JVMKill agent component if not already set
	if g.jvmkill == nil {
		g.jvmkill = NewJVMKillAgent(g.ctx, g.jreDir, g.version)
	}

	// Finalize JVMKill agent
	if err := g.jvmkill.Finalize(); err != nil {
		g.ctx.Log.Warning("Failed to finalize JVMKill agent: %s", err.Error())
		// Non-fatal
	}

	// Reconstruct Memory Calculator component if not already set
	if g.memoryCalc == nil {
		g.memoryCalc = NewMemoryCalculator(g.ctx, g.jreDir, g.version, javaMajorVersion)
	}

	// Finalize Memory Calculator
	if err := g.memoryCalc.Finalize(); err != nil {
		g.ctx.Log.Warning("Failed to finalize Memory Calculator: %s", err.Error())
		// Non-fatal
	}

	g.ctx.Log.Info("GraalVM JRE finalization complete")
	return nil
}

// JavaHome returns the path to JAVA_HOME
func (g *GraalVMJRE) JavaHome() string {
	return g.javaHome
}

// Version returns the installed JRE version
func (g *GraalVMJRE) Version() string {
	return g.installedVersion
}

// MemoryCalculatorCommand returns the shell command snippet to run memory calculator at runtime
func (g *GraalVMJRE) MemoryCalculatorCommand() string {
	if g.memoryCalc == nil {
		return ""
	}
	return g.memoryCalc.GetCalculatorCommand()
}

// findJavaHome locates the actual JAVA_HOME directory after extraction
// GraalVM tarballs usually extract to graalvm-* or jdk-* subdirectories
func (g *GraalVMJRE) findJavaHome() (string, error) {
	entries, err := os.ReadDir(g.jreDir)
	if err != nil {
		return "", fmt.Errorf("failed to read JRE directory: %w", err)
	}

	// Look for graalvm-*, jdk-*, or jre-* subdirectory
	for _, entry := range entries {
		if entry.IsDir() {
			name := entry.Name()
			// Check for GraalVM directory patterns
			if len(name) > 7 && name[:7] == "graalvm" {
				path := filepath.Join(g.jreDir, name)
				// Verify it has a bin directory with java
				if _, err := os.Stat(filepath.Join(path, "bin", "java")); err == nil {
					return path, nil
				}
			}
			// Also check for standard jdk/jre patterns
			if len(name) > 3 && (name[:3] == "jdk" || name[:3] == "jre") {
				path := filepath.Join(g.jreDir, name)
				if _, err := os.Stat(filepath.Join(path, "bin", "java")); err == nil {
					return path, nil
				}
			}
		}
	}

	// If no subdirectory found, check if jreDir itself is valid
	if _, err := os.Stat(filepath.Join(g.jreDir, "bin", "java")); err == nil {
		return g.jreDir, nil
	}

	return "", fmt.Errorf("could not find valid JAVA_HOME in %s", g.jreDir)
}

// writeProfileDScript creates a profile.d script that exports JAVA_HOME, JRE_HOME, and PATH at runtime
// Delegates to the shared helper function in jre.go
func (g *GraalVMJRE) writeProfileDScript() error {
	return WriteJavaHomeProfileD(g.ctx, g.jreDir, g.javaHome)
}
