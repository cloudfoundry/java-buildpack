package jres

import (
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"os"
	"path/filepath"
)

// SapMachineJRE implements the JRE interface for SAP Machine OpenJDK
type SapMachineJRE struct {
	ctx              *common.Context
	jreDir           string
	version          string
	javaHome         string
	memoryCalc       *MemoryCalculator
	jvmkill          *JVMKillAgent
	installedVersion string
}

// NewSapMachineJRE creates a new SAP Machine JRE provider
func NewSapMachineJRE(ctx *common.Context) *SapMachineJRE {
	jreDir := filepath.Join(ctx.Stager.DepDir(), "jre")

	return &SapMachineJRE{
		ctx:    ctx,
		jreDir: jreDir,
	}
}

// Name returns the name of this JRE provider
func (s *SapMachineJRE) Name() string {
	return "SapMachine"
}

// Detect returns true if SAP Machine JRE should be used
// SAP Machine is selected via JBP_CONFIG_SAP_MACHINE_JRE environment variable
func (s *SapMachineJRE) Detect() (bool, error) {
	return DetectJREByEnv("sapmachine"), nil
}

// Supply installs the SAP Machine JRE and its components
func (s *SapMachineJRE) Supply() error {
	s.ctx.Log.BeginStep("Installing SAP Machine JRE")

	// Determine version
	dep, err := GetJREVersion(s.ctx, "sapmachine")
	if err != nil {
		return fmt.Errorf("failed to determine SAP Machine version from manifest: %w", err)
	}

	s.version = dep.Version
	s.ctx.Log.Info("Installing SAP Machine %s", s.version)

	// Install JRE
	if err := s.ctx.Installer.InstallDependency(dep, s.jreDir); err != nil {
		return fmt.Errorf("failed to install SAP Machine: %w", err)
	}

	// Find the actual JAVA_HOME (handle nested directories from tar extraction)
	javaHome, err := s.findJavaHome()
	if err != nil {
		return fmt.Errorf("failed to find JAVA_HOME: %w", err)
	}
	s.javaHome = javaHome
	s.installedVersion = s.version

	// Write profile.d script for runtime environment
	if err := s.writeProfileDScript(); err != nil {
		s.ctx.Log.Warning("Could not write java.sh profile.d script: %s", err.Error())
	} else {
		s.ctx.Log.Debug("Created profile.d script: java.sh")
	}

	// Determine Java major version
	javaMajorVersion, err := common.DetermineJavaVersion(javaHome)
	if err != nil {
		s.ctx.Log.Warning("Could not determine Java version: %s", err.Error())
		javaMajorVersion = 17 // default for SAP Machine
	}
	s.ctx.Log.Info("Detected Java major version: %d", javaMajorVersion)

	// Install JVMKill agent
	s.jvmkill = NewJVMKillAgent(s.ctx, s.jreDir, s.version)
	if err := s.jvmkill.Supply(); err != nil {
		s.ctx.Log.Warning("Failed to install JVMKill agent: %s (continuing)", err.Error())
		// Non-fatal - continue without jvmkill
	}

	// Install Memory Calculator
	s.memoryCalc = NewMemoryCalculator(s.ctx, s.jreDir, s.version, javaMajorVersion)
	if err := s.memoryCalc.Supply(); err != nil {
		s.ctx.Log.Warning("Failed to install Memory Calculator: %s (continuing)", err.Error())
		// Non-fatal - continue without memory calculator
	}

	s.ctx.Log.Info("SAP Machine JRE installation complete")
	return nil
}

// Finalize performs final JRE configuration
func (s *SapMachineJRE) Finalize() error {
	s.ctx.Log.BeginStep("Finalizing SAP Machine JRE configuration")

	// Find the actual JAVA_HOME (needed if finalize is called on a fresh instance)
	if s.javaHome == "" {
		javaHome, err := s.findJavaHome()
		if err != nil {
			s.ctx.Log.Warning("Failed to find JAVA_HOME: %s", err.Error())
		} else {
			s.javaHome = javaHome
		}
	}

	// Set JAVA_HOME in environment for frameworks that need it during finalize phase
	// (e.g., Luna Security Provider, Container Security Provider)
	if s.javaHome != "" {
		if err := os.Setenv("JAVA_HOME", s.javaHome); err != nil {
			s.ctx.Log.Warning("Failed to set JAVA_HOME environment variable: %s", err.Error())
		} else {
			s.ctx.Log.Debug("Set JAVA_HOME=%s", s.javaHome)
		}
	}

	// Determine Java major version for memory calculator
	javaMajorVersion := 17 // default
	if s.javaHome != "" {
		if ver, err := common.DetermineJavaVersion(s.javaHome); err == nil {
			javaMajorVersion = ver
		}
	}

	// Reconstruct JVMKill agent component if not already set
	if s.jvmkill == nil {
		s.jvmkill = NewJVMKillAgent(s.ctx, s.jreDir, s.version)
	}

	// Finalize JVMKill agent
	if err := s.jvmkill.Finalize(); err != nil {
		s.ctx.Log.Warning("Failed to finalize JVMKill agent: %s", err.Error())
		// Non-fatal
	}

	// Reconstruct Memory Calculator component if not already set
	if s.memoryCalc == nil {
		s.memoryCalc = NewMemoryCalculator(s.ctx, s.jreDir, s.version, javaMajorVersion)
	}

	// Finalize Memory Calculator
	if err := s.memoryCalc.Finalize(); err != nil {
		s.ctx.Log.Warning("Failed to finalize Memory Calculator: %s", err.Error())
		// Non-fatal
	}

	s.ctx.Log.Info("SAP Machine JRE finalization complete")
	return nil
}

// JavaHome returns the path to JAVA_HOME
func (s *SapMachineJRE) JavaHome() string {
	return s.javaHome
}

// Version returns the installed JRE version
func (s *SapMachineJRE) Version() string {
	return s.installedVersion
}

// MemoryCalculatorCommand returns the shell command snippet to run memory calculator at runtime
func (s *SapMachineJRE) MemoryCalculatorCommand() string {
	if s.memoryCalc == nil {
		return ""
	}
	return s.memoryCalc.GetCalculatorCommand()
}

// findJavaHome locates the actual JAVA_HOME directory after extraction
// SAP Machine tarballs usually extract to sapmachine-* or jdk-* subdirectories
func (s *SapMachineJRE) findJavaHome() (string, error) {
	entries, err := os.ReadDir(s.jreDir)
	if err != nil {
		return "", fmt.Errorf("failed to read JRE directory: %w", err)
	}

	// Look for sapmachine-*, jdk-*, or jre-* subdirectory
	for _, entry := range entries {
		if entry.IsDir() {
			name := entry.Name()
			// Check for SAP Machine directory patterns
			if len(name) > 10 && name[:10] == "sapmachine" {
				path := filepath.Join(s.jreDir, name)
				// Verify it has a bin directory with java
				if _, err := os.Stat(filepath.Join(path, "bin", "java")); err == nil {
					return path, nil
				}
			}
			// Also check for standard jdk/jre patterns
			if len(name) > 3 && (name[:3] == "jdk" || name[:3] == "jre") {
				path := filepath.Join(s.jreDir, name)
				if _, err := os.Stat(filepath.Join(path, "bin", "java")); err == nil {
					return path, nil
				}
			}
		}
	}

	// If no subdirectory found, check if jreDir itself is valid
	if _, err := os.Stat(filepath.Join(s.jreDir, "bin", "java")); err == nil {
		return s.jreDir, nil
	}

	return "", fmt.Errorf("could not find valid JAVA_HOME in %s", s.jreDir)
}

// writeProfileDScript creates a profile.d script that exports JAVA_HOME, JRE_HOME, and PATH at runtime
// Delegates to the shared helper function in jre.go
func (s *SapMachineJRE) writeProfileDScript() error {
	return WriteJavaHomeProfileD(s.ctx, s.jreDir, s.javaHome)
}
