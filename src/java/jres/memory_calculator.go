package jres

import (
	"archive/zip"
	"bytes"
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

// MemoryCalculator manages the Java memory calculator
// The memory calculator determines optimal JVM memory settings based on available container memory
type MemoryCalculator struct {
	ctx              *common.Context
	jreDir           string
	jreVersion       string
	javaMajorVersion int
	calculatorPath   string
	version          string
	classCount       int
	stackThreads     int
	headroom         int
}

// NewMemoryCalculator creates a new memory calculator
func NewMemoryCalculator(ctx *common.Context, jreDir, jreVersion string, javaMajorVersion int) *MemoryCalculator {
	return &MemoryCalculator{
		ctx:              ctx,
		jreDir:           jreDir,
		jreVersion:       jreVersion,
		javaMajorVersion: javaMajorVersion,
		stackThreads:     DefaultStackThreads,
		headroom:         DefaultHeadroom,
	}
}

// Name returns the component name
func (m *MemoryCalculator) Name() string {
	return "Memory Calculator"
}

// Supply installs the memory calculator
func (m *MemoryCalculator) Supply() error {
	m.ctx.Log.Info("Installing Memory Calculator")

	// Get memory calculator version from manifest
	dep, err := m.ctx.Manifest.DefaultVersion("memory-calculator")
	if err != nil {
		return fmt.Errorf("unable to determine memory calculator version: %w", err)
	}

	m.version = dep.Version
	m.ctx.Log.Debug("Memory Calculator version: %s", m.version)

	// Create bin directory
	binDir := filepath.Join(m.jreDir, "bin")
	if err := os.MkdirAll(binDir, 0755); err != nil {
		return fmt.Errorf("failed to create bin directory: %w", err)
	}

	// Download to temporary location (it's a tar.gz)
	tempDir := filepath.Join(m.ctx.Stager.DepDir(), "tmp", "memory-calculator")
	if err := os.MkdirAll(tempDir, 0755); err != nil {
		return fmt.Errorf("failed to create temp directory: %w", err)
	}

	// Install (extract) the tarball to temp directory
	if err := m.ctx.Installer.InstallDependency(dep, tempDir); err != nil {
		return fmt.Errorf("failed to install memory calculator: %w", err)
	}

	// Find the extracted binary (try various possible names)
	possibleNames := []string{
		"java-buildpack-memory-calculator", // v4.x format
		"memory-calculator-linux",          // older format
		"memory-calculator-darwin",         // darwin for local testing
	}

	var calculatorBinary string
	for _, name := range possibleNames {
		testPath := filepath.Join(tempDir, name)
		if _, err := os.Stat(testPath); err == nil {
			calculatorBinary = testPath
			break
		}
	}

	if calculatorBinary == "" {
		return fmt.Errorf("could not find memory calculator binary in %s", tempDir)
	}

	// Move to final location with version
	finalPath := filepath.Join(binDir, fmt.Sprintf("java-buildpack-memory-calculator-%s", m.version))
	if err := os.Rename(calculatorBinary, finalPath); err != nil {
		// Try copy if rename fails (cross-device link)
		if err := copyFile(calculatorBinary, finalPath); err != nil {
			return fmt.Errorf("failed to move memory calculator: %w", err)
		}
	}

	// Make it executable
	if err := os.Chmod(finalPath, 0755); err != nil {
		return fmt.Errorf("failed to chmod memory calculator: %w", err)
	}

	m.calculatorPath = finalPath

	// Count classes in the application
	if err := m.countClasses(); err != nil {
		m.ctx.Log.Warning("Failed to count classes: %s (using default)", err.Error())
		m.classCount = 0 // Will be calculated as 35% of actual later
	}

	m.ctx.Log.Info("Memory Calculator installed: Loaded Classes: %d, Threads: %d",
		m.classCount, m.stackThreads)

	// Clean up temp directory
	os.RemoveAll(tempDir)

	return nil
}

// detectInstalledCalculator checks if memory calculator was previously installed
func (m *MemoryCalculator) detectInstalledCalculator() {
	binDir := filepath.Join(m.jreDir, "bin")

	// Try to find java-buildpack-memory-calculator-* files
	entries, err := os.ReadDir(binDir)
	if err != nil {
		return
	}

	prefix := "java-buildpack-memory-calculator-"
	for _, entry := range entries {
		name := entry.Name()
		if len(name) > len(prefix) && name[:len(prefix)] == prefix {
			m.calculatorPath = filepath.Join(binDir, name)
			m.ctx.Log.Debug("Detected installed memory calculator: %s", m.calculatorPath)

			// Also need to re-count classes if classCount is 0
			if m.classCount == 0 {
				if err := m.countClasses(); err != nil {
					m.ctx.Log.Warning("Failed to count classes: %s", err.Error())
				}
			}
			return
		}
	}
}

// Finalize configures the memory calculator in the startup command
func (m *MemoryCalculator) Finalize() error {
	// If calculatorPath not set, try to detect it from previous installation
	if m.calculatorPath == "" {
		m.detectInstalledCalculator()
	}

	if m.calculatorPath == "" {
		return nil // Not installed
	}

	m.ctx.Log.Info("Configuring Memory Calculator")

	// The memory calculator command will be added to the startup script
	// It's executed at runtime to calculate memory based on actual container limits
	// Format: CALCULATED_MEMORY=$(calculator args) && JAVA_OPTS="$JAVA_OPTS $CALCULATED_MEMORY"

	// We'll write this to a shell script that containers can source
	memoryCalcScript := filepath.Join(m.ctx.Stager.DepDir(), "bin", "memory_calculator.sh")
	if err := os.MkdirAll(filepath.Dir(memoryCalcScript), 0755); err != nil {
		return fmt.Errorf("failed to create bin directory: %w", err)
	}

	// Build calculator command (v4.x format)
	calculatorCmd := m.buildCalculatorCommand()

	scriptContent := fmt.Sprintf(`#!/bin/bash
# Memory Calculator - calculates optimal JVM memory settings
if [ -n "$MEMORY_LIMIT" ]; then
  CALCULATED_MEMORY=$(%s)
  echo "JVM Memory Configuration: $CALCULATED_MEMORY"
  export JAVA_OPTS="$JAVA_OPTS $CALCULATED_MEMORY"
fi

# Set MALLOC_ARENA_MAX to reduce memory overhead
export MALLOC_ARENA_MAX=2
`, calculatorCmd)

	if err := os.WriteFile(memoryCalcScript, []byte(scriptContent), 0755); err != nil {
		return fmt.Errorf("failed to write memory calculator script: %w", err)
	}

	m.ctx.Log.Info("Memory Calculator configured")

	return nil
}

// buildCalculatorCommand builds the memory calculator command with all arguments (v4.x format)
func (m *MemoryCalculator) buildCalculatorCommand() string {
	args := []string{
		m.calculatorPath,
		"--total-memory=$MEMORY_LIMIT",
	}

	if m.headroom > 0 {
		args = append(args, fmt.Sprintf("--head-room=%d", m.headroom))
	}

	// Use default class count if counting failed (v4 calculator requires this parameter)
	classCount := m.classCount
	if classCount == 0 {
		classCount = int(float64(DefaultClassCount) * 0.35) // Apply same 35% factor
	}

	args = append(args,
		fmt.Sprintf("--loaded-class-count=%d", classCount),
		fmt.Sprintf("--thread-count=%d", m.stackThreads),
		`--jvm-options="$JAVA_OPTS"`,
	)

	return strings.Join(args, " ")
}

// countClasses counts .class and .groovy files in the application
// This is used by the memory calculator to determine metaspace/permgen size
func (m *MemoryCalculator) countClasses() error {
	buildDir := m.ctx.Stager.BuildDir()

	classCount := 0

	// Walk the build directory
	err := filepath.Walk(buildDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // Skip files we can't access
		}

		if info.IsDir() {
			return nil
		}

		// Count .class files
		if strings.HasSuffix(path, ".class") {
			classCount++
			return nil
		}

		// Count .groovy files
		if strings.HasSuffix(path, ".groovy") {
			classCount++
			return nil
		}

		// Count classes in .jar files
		if strings.HasSuffix(path, ".jar") {
			jarClassCount, err := m.countClassesInJar(path)
			if err != nil {
				m.ctx.Log.Debug("Failed to count classes in %s: %s", path, err.Error())
				return nil
			}
			classCount += jarClassCount
		}

		return nil
	})

	if err != nil {
		return fmt.Errorf("failed to walk build directory: %w", err)
	}

	// Add JRE classes for Java 9+
	if m.javaMajorVersion >= 9 {
		classCount += Java9ClassCount
	}

	// Apply 35% factor as per original buildpack logic
	// This accounts for the fact that not all classes are loaded
	m.classCount = int(float64(classCount) * 0.35)

	m.ctx.Log.Debug("Counted %d classes (%.0f%% of %d total)", m.classCount, 35.0, classCount)

	return nil
}

// countClassesInJar counts .class and .groovy files in a JAR file
func (m *MemoryCalculator) countClassesInJar(jarPath string) (int, error) {
	// Open JAR file as ZIP
	reader, err := zip.OpenReader(jarPath)
	if err != nil {
		return 0, err
	}
	defer reader.Close()

	count := 0
	for _, file := range reader.File {
		if strings.HasSuffix(file.Name, ".class") || strings.HasSuffix(file.Name, ".groovy") {
			count++
		}
	}

	return count, nil
}

// GetCalculatorCommand returns the memory calculator command for use in startup scripts
// This is called by containers when building their start commands
// Returns a shell command snippet that:
// 1. Runs the memory calculator with runtime $MEMORY_LIMIT
// 2. Echoes the calculated memory settings
// 3. Appends the settings to $JAVA_OPTS
// 4. Sets MALLOC_ARENA_MAX to reduce memory overhead
func (m *MemoryCalculator) GetCalculatorCommand() string {
	if m.calculatorPath == "" {
		return ""
	}

	// Convert staging path to runtime path
	runtimePath := m.convertToRuntimePath(m.calculatorPath)

	// Build calculator args (v4.x uses double-dash long flags)
	args := []string{
		runtimePath,
		"--total-memory=$MEMORY_LIMIT",
	}

	if m.headroom > 0 {
		args = append(args, fmt.Sprintf("--head-room=%d", m.headroom))
	}

	// Use default class count if counting failed (v4 calculator requires this parameter)
	classCount := m.classCount
	if classCount == 0 {
		classCount = int(float64(DefaultClassCount) * 0.35) // Apply same 35% factor
	}

	args = append(args,
		fmt.Sprintf("--loaded-class-count=%d", classCount),
		fmt.Sprintf("--thread-count=%d", m.stackThreads),
		`--jvm-options="$JAVA_OPTS"`,
	)

	calcCmd := strings.Join(args, " ")

	return fmt.Sprintf(`CALCULATED_MEMORY=$(%s) && echo JVM Memory Configuration: $CALCULATED_MEMORY && JAVA_OPTS="$JAVA_OPTS $CALCULATED_MEMORY" && MALLOC_ARENA_MAX=2`, calcCmd)
}

// convertToRuntimePath converts a staging path to a runtime path
// Example: /tmp/staging/deps/0/jre/bin/calculator -> /home/vcap/deps/0/jre/bin/calculator
func (m *MemoryCalculator) convertToRuntimePath(stagingPath string) string {
	depsIdx := m.ctx.Stager.DepsIdx()

	// Extract the relative path from deps/X/ onwards
	// stagingPath: /tmp/.../deps/0/jre/bin/java-buildpack-memory-calculator-X.X.X
	// We want: /home/vcap/deps/0/jre/bin/java-buildpack-memory-calculator-X.X.X

	// Find "jre/bin/" in the path
	if idx := strings.Index(stagingPath, "jre/bin/"); idx != -1 {
		relativePath := stagingPath[idx:]
		return fmt.Sprintf("/home/vcap/deps/%s/%s", depsIdx, relativePath)
	}

	// Fallback: just use the filename
	filename := filepath.Base(stagingPath)
	return fmt.Sprintf("/home/vcap/deps/%s/jre/bin/%s", depsIdx, filename)
}

// LoadConfig loads memory calculator configuration from environment/config
func (m *MemoryCalculator) LoadConfig() {
	// Check for environment overrides
	// JBP_CONFIG_OPEN_JDK_JRE='{memory_calculator: {stack_threads: 300}}'

	// For now, using defaults
	// In production, we'd parse JSON from environment variables

	// Check specific environment variables
	if val := os.Getenv("MEMORY_CALCULATOR_STACK_THREADS"); val != "" {
		if threads, err := strconv.Atoi(val); err == nil {
			m.stackThreads = threads
		}
	}

	if val := os.Getenv("MEMORY_CALCULATOR_HEADROOM"); val != "" {
		if headroom, err := strconv.Atoi(val); err == nil {
			m.headroom = headroom
		}
	}
}

// Helper function to copy files
func copyFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, data, 0755)
}

// RunMemoryCalculator runs the memory calculator and returns the calculated JAVA_OPTS
// This is primarily for testing
func (m *MemoryCalculator) RunMemoryCalculator(memoryLimit string) (string, error) {
	if m.calculatorPath == "" {
		return "", fmt.Errorf("memory calculator not installed")
	}

	args := []string{
		"--total-memory=" + memoryLimit,
		fmt.Sprintf("--loaded-class-count=%d", m.classCount),
		fmt.Sprintf("--thread-count=%d", m.stackThreads),
		`--jvm-options=""`,
	}

	if m.headroom > 0 {
		args = append(args, fmt.Sprintf("--head-room=%d", m.headroom))
	}

	cmd := exec.Command(m.calculatorPath, args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("memory calculator failed: %s - %s", err.Error(), stderr.String())
	}

	return strings.TrimSpace(stdout.String()), nil
}
