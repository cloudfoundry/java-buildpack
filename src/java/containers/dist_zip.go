package containers

import (
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"os"
	"path/filepath"
	"strings"
)

// DistZipContainer handles distribution ZIP applications
// (applications with bin/ and lib/ structure, typically from Gradle's distZip)
type DistZipContainer struct {
	context     *common.Context
	startScript string
}

// NewDistZipContainer creates a new Dist ZIP container
func NewDistZipContainer(ctx *common.Context) *DistZipContainer {
	return &DistZipContainer{
		context: ctx,
	}
}

// Detect checks if this is a Dist ZIP application
func (d *DistZipContainer) Detect() (string, error) {
	matches, err := d.findDistZipMatches()
	if err != nil {
		return "", err
	}

	if len(matches) == 0 {
		return "", nil
	}

	if len(matches) > 1 {
		d.context.Log.Debug("Rejecting Dist ZIP detection - multiple bin/lib structures detected")
		return "", nil
	}

	d.startScript = matches[0]
	d.context.Log.Debug("Detected Dist ZIP application with start script: %s", d.startScript)
	return "Dist ZIP", nil
}

func (d *DistZipContainer) findDistZipMatches() ([]string, error) {
	buildDir := d.context.Stager.BuildDir()
	type candidate struct {
		abs string
		rel string
	}

	candidates := []candidate{{abs: buildDir}}

	entries, err := os.ReadDir(buildDir)
	if err != nil {
		d.context.Log.Debug("Unable to list build dir for Dist ZIP detection: %s", err.Error())
	} else {
		for _, entry := range entries {
			if entry.IsDir() {
				candidates = append(candidates, candidate{
					abs: filepath.Join(buildDir, entry.Name()),
					rel: entry.Name(),
				})
			}
		}
	}

	var matches []string
	for _, c := range candidates {
		binDir := filepath.Join(c.abs, "bin")
		libDir := filepath.Join(c.abs, "lib")

		if !isDir(binDir) || !isDir(libDir) {
			continue
		}

		if d.isPlayFramework(libDir) {
			d.context.Log.Debug("Rejecting Dist ZIP detection - Play Framework JAR found in %s", libDir)
			continue
		}

		script := findUnixStartScript(binDir)
		if script == "" {
			continue
		}

		relPath := filepath.Join(c.rel, "bin", script)
		relPath = strings.TrimPrefix(relPath, string(filepath.Separator))
		matches = append(matches, relPath)
	}

	return matches, nil
}

func isDir(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return info.IsDir()
}

func findUnixStartScript(binDir string) string {
	entries, err := os.ReadDir(binDir)
	if err != nil {
		return ""
	}

	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) == ".bat" {
			continue
		}
		return entry.Name()
	}

	return ""
}

// isPlayFramework checks if a lib directory contains Play Framework JARs
func (d *DistZipContainer) isPlayFramework(libDir string) bool {
	entries, err := os.ReadDir(libDir)
	if err != nil {
		return false
	}

	// Check for Play Framework JAR patterns:
	// - com.typesafe.play.play_*.jar (Play 2.2+)
	// - play.play_*.jar (Play 2.0)
	// - play_*.jar (Play 2.1)
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if strings.Contains(name, "com.typesafe.play.play_") ||
			strings.HasPrefix(name, "play.play_") ||
			(strings.HasPrefix(name, "play_") && strings.HasSuffix(name, ".jar")) {
			return true
		}
	}

	return false
}

// Supply installs Dist ZIP dependencies
func (d *DistZipContainer) Supply() error {
	d.context.Log.BeginStep("Supplying Dist ZIP")

	// For Dist ZIP apps, the structure is already provided
	// We may need to:
	// 1. Ensure scripts are executable
	// 2. Install support utilities

	// Make bin scripts executable
	if err := d.makeScriptsExecutable(); err != nil {
		d.context.Log.Warning("Could not make scripts executable: %s", err.Error())
	}

	return nil
}

// makeScriptsExecutable ensures all scripts in bin/ are executable
func (d *DistZipContainer) makeScriptsExecutable() error {
	buildDir := d.context.Stager.BuildDir()

	binDirs := map[string]struct{}{
		filepath.Join(buildDir, "bin"):                     {},
		filepath.Join(buildDir, "application-root", "bin"): {},
	}

	if d.startScript != "" {
		scriptDir := filepath.Dir(d.startScript)
		if scriptDir != "" && scriptDir != "." {
			binDirs[filepath.Join(buildDir, scriptDir)] = struct{}{}
		}
	}

	for dir := range binDirs {
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, entry := range entries {
			if entry.IsDir() || filepath.Ext(entry.Name()) == ".bat" {
				continue
			}
			scriptPath := filepath.Join(dir, entry.Name())
			if err := os.Chmod(scriptPath, 0755); err != nil {
				d.context.Log.Warning("Could not make %s executable: %s", scriptPath, err.Error())
			}
		}
	}

	return nil
}

// Finalize performs final Dist ZIP configuration
func (d *DistZipContainer) Finalize() error {
	d.context.Log.BeginStep("Finalizing Dist ZIP")
	d.context.Log.Info("DistZip Finalize: Starting (startScript=%s)", d.startScript)

	scriptDir := filepath.Dir(d.startScript)
	if scriptDir == "" || scriptDir == "." {
		scriptDir = "bin"
	}
	scriptDir = filepath.ToSlash(scriptDir)

	// Collect additional libraries (JVMKill agent, frameworks, etc.)
	additionalLibs := d.collectAdditionalLibraries()
	d.context.Log.Info("Found %d additional libraries for CLASSPATH", len(additionalLibs))

	// Build CLASSPATH from additional libraries
	// Convert staging paths to runtime paths
	classpathParts := d.buildRuntimeClasspath(additionalLibs)

	// Write profile.d script that sets up environment variables
	// This follows the immutable BuildDir pattern: configure via environment, don't modify files
	envContent := fmt.Sprintf(`export DEPS_DIR=${DEPS_DIR:-/home/vcap/deps}
export DIST_ZIP_HOME=$HOME
export DIST_ZIP_BIN=$HOME/%s
export PATH=$DIST_ZIP_BIN:$PATH

# Prepend additional libraries to CLASSPATH
# Most distZip scripts respect CLASSPATH environment variable
# This includes JVMKill agent, framework JARs, JDBC drivers, etc.
`, scriptDir)

	// Add CLASSPATH if we have additional libraries
	if len(classpathParts) > 0 {
		classpathValue := strings.Join(classpathParts, ":")
		envContent += fmt.Sprintf("export CLASSPATH=\"%s:${CLASSPATH:-}\"\n", classpathValue)
		d.context.Log.Info("Configured CLASSPATH with %d additional libraries", len(classpathParts))
	}

	if err := d.context.Stager.WriteProfileD("dist_zip.sh", envContent); err != nil {
		d.context.Log.Warning("Could not write dist_zip.sh profile.d script: %s", err.Error())
	} else {
		d.context.Log.Debug("Created profile.d script: dist_zip.sh")
	}

	// Configure JAVA_OPTS to be picked up by startup scripts
	// Note: JVMKill agent is configured by the JRE component via .profile.d/java_opts.sh
	javaOpts := []string{
		"-Djava.io.tmpdir=$TMPDIR",
		"-XX:+ExitOnOutOfMemoryError",
	}

	// Most distZip scripts respect JAVA_OPTS environment variable
	javaOptsScript := fmt.Sprintf("export JAVA_OPTS=\"%s\"\n", strings.Join(javaOpts, " "))
	if err := d.context.Stager.WriteProfileD("dist_zip_java_opts.sh", javaOptsScript); err != nil {
		return fmt.Errorf("failed to write JAVA_OPTS profile.d script: %w", err)
	}

	d.context.Log.Info("DistZip finalization complete (using environment variables, not modifying scripts)")
	return nil
}

// buildRuntimeClasspath converts staging library paths to runtime paths for CLASSPATH
func (d *DistZipContainer) buildRuntimeClasspath(libs []string) []string {
	depsDir := d.context.Stager.DepDir()
	buildDir := d.context.Stager.BuildDir()
	depsIdx := d.context.Stager.DepsIdx()
	var classpathParts []string

	for _, lib := range libs {
		var runtimePath string

		// Check if library is in deps directory (e.g., framework JARs, agents)
		if strings.HasPrefix(lib, depsDir) {
			// Convert staging absolute path to runtime path
			// Staging: /tmp/staging/deps/<idx>/new_relic_agent/newrelic.jar
			// Runtime: $DEPS_DIR/<idx>/new_relic_agent/newrelic.jar
			relPath := strings.TrimPrefix(lib, depsDir)
			relPath = strings.TrimPrefix(relPath, "/") // Remove leading slash
			relPath = filepath.ToSlash(relPath)        // Normalize slashes
			runtimePath = fmt.Sprintf("$DEPS_DIR/%s/%s", depsIdx, relPath)
		} else if strings.HasPrefix(lib, buildDir) {
			// Library is in build directory (unlikely for additional libs, but handle it)
			relPath, err := filepath.Rel(buildDir, lib)
			if err != nil {
				d.context.Log.Warning("Could not calculate relative path for %s: %s", lib, err.Error())
				continue
			}
			relPath = filepath.ToSlash(relPath)
			runtimePath = fmt.Sprintf("$HOME/%s", relPath)
		} else {
			// Fallback: library path doesn't match expected patterns
			d.context.Log.Warning("Library path %s doesn't match deps or build directory, using as-is", lib)
			runtimePath = lib
		}

		classpathParts = append(classpathParts, runtimePath)
	}

	return classpathParts
}

// collectAdditionalLibraries gathers all additional libraries that should be added to CLASSPATH
// This includes framework-provided JAR libraries installed during supply phase
func (d *DistZipContainer) collectAdditionalLibraries() []string {
	var libs []string
	depsDir := d.context.Stager.DepDir()

	// Scan $DEPS_DIR/<idx>/ for all framework directories
	entries, err := os.ReadDir(depsDir)
	if err != nil {
		d.context.Log.Debug("Unable to read deps directory: %s", err.Error())
		return libs
	}

	// Iterate through each framework directory
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		frameworkDir := filepath.Join(depsDir, entry.Name())

		// Find all *.jar files in this framework directory
		jarPattern := filepath.Join(frameworkDir, "*.jar")
		matches, err := filepath.Glob(jarPattern)
		if err != nil {
			d.context.Log.Debug("Error globbing JARs in %s: %s", frameworkDir, err.Error())
			continue
		}

		// Add all found JARs to the list
		// NOTE: Native libraries (.so, .dylib files like jvmkill) are NOT added here
		// Native libraries are loaded via -agentpath in JAVA_OPTS
		for _, jar := range matches {
			// Skip native libraries - only include .jar files
			if filepath.Ext(jar) == ".jar" {
				libs = append(libs, jar)
			}
		}
	}

	return libs
}

// Release returns the Dist ZIP startup command
// Uses absolute path to ensure script is found at runtime
func (d *DistZipContainer) Release() (string, error) {
	// Use the detected start script
	if d.startScript == "" {
		// Try to detect again
		if _, err := d.Detect(); err != nil || d.startScript == "" {
			return "", fmt.Errorf("no start script found in bin/ directory")
		}
	}

	scriptPath := filepath.ToSlash(d.startScript)
	cmd := fmt.Sprintf("$HOME/%s", scriptPath)

	return cmd, nil
}
