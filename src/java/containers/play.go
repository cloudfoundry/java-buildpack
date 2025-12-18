package containers

import (
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// PlayContainer represents a Play Framework application container
type PlayContainer struct {
	context     *common.Context
	playType    string // "pre22_dist", "pre22_staged", "post22_dist", "post22_staged"
	playVersion string
	startScript string
	libDir      string
}

// NewPlayContainer creates a new Play Framework container
func NewPlayContainer(ctx *common.Context) *PlayContainer {
	return &PlayContainer{
		context: ctx,
	}
}

// Detect checks if this is a Play Framework application
func (p *PlayContainer) Detect() (string, error) {
	buildDir := p.context.Stager.BuildDir()

	p.context.Log.Debug("Play: Checking buildDir: %s", buildDir)

	// First, validate that we don't have ambiguous configuration (hybrid apps)
	if err := p.Validate(); err != nil {
		p.context.Log.Debug("Play: Validation failed: %v", err)
		return "", err
	}

	// Try to detect Play Framework type in order of specificity
	// Order matters to avoid ambiguous detection
	// Check staged apps (more specific - lib/staged only) before dist apps (less specific - has start scripts)

	// 1. Try Pre22Staged (Play 2.0-2.1 staged app - only staged/ with JARs)
	p.context.Log.Debug("Play: Trying Pre22Staged detection")
	if p.detectPre22Staged(buildDir) {
		p.context.Log.Info("Play: Detected Pre22Staged - version %s", p.playVersion)
		return "Play", nil
	}

	// 2. Try Post22Staged (Play 2.2+ staged app - only lib/ with JARs)
	p.context.Log.Debug("Play: Trying Post22Staged detection")
	if p.detectPost22Staged(buildDir) {
		p.context.Log.Info("Play: Detected Post22Staged - version %s", p.playVersion)
		return "Play", nil
	}

	// 3. Try Post22Dist (Play 2.2+ distributed app in application-root/bin)
	p.context.Log.Debug("Play: Trying Post22Dist detection")
	if p.detectPost22Dist(buildDir) {
		p.context.Log.Info("Play: Detected Post22Dist - version %s", p.playVersion)
		return "Play", nil
	}

	// 4. Try Pre22Dist (Play 2.0-2.1 distributed app in application-root/)
	p.context.Log.Debug("Play: Trying Pre22Dist detection")
	if p.detectPre22Dist(buildDir) {
		p.context.Log.Info("Play: Detected Pre22Dist - version %s", p.playVersion)
		return "Play", nil
	}

	p.context.Log.Debug("Play: No Play Framework detected")
	return "", nil
}

// detectPost22Dist detects Play 2.2+ distributed applications
// Structure: application-root/bin/<script>, application-root/lib/com.typesafe.play.play_*.jar
func (p *PlayContainer) detectPost22Dist(buildDir string) bool {
	// Check for application-root/bin/ directory
	binDir := filepath.Join(buildDir, "application-root", "bin")
	binStat, binErr := os.Stat(binDir)
	if binErr != nil || !binStat.IsDir() {
		return false
	}

	// Check for application-root/lib/ directory
	libDir := filepath.Join(buildDir, "application-root", "lib")
	libStat, libErr := os.Stat(libDir)
	if libErr != nil || !libStat.IsDir() {
		return false
	}

	// Find Play JAR in lib/ (com.typesafe.play.play_*.jar)
	playJar, version := p.findPlayJar(libDir)
	if playJar == "" {
		return false
	}

	// Parse version - must be 2.2 or higher
	if !p.isPost22Version(version) {
		return false
	}

	// Find start script in bin/ (non-.bat file)
	startScript := p.findStartScript(binDir)
	if startScript == "" {
		return false
	}

	p.playType = "post22_dist"
	p.playVersion = version
	p.startScript = filepath.Join("application-root", "bin", startScript)
	p.libDir = libDir
	p.context.Log.Debug("Detected Play Framework %s (Post22Dist)", version)
	return true
}

// detectPost22Staged detects Play 2.2+ staged applications
// Structure: lib/com.typesafe.play.play_*.jar (may or may not have bin/ with script)
func (p *PlayContainer) detectPost22Staged(buildDir string) bool {
	// Check for lib/ directory at root
	libDir := filepath.Join(buildDir, "lib")
	libStat, libErr := os.Stat(libDir)
	if libErr != nil || !libStat.IsDir() {
		return false
	}

	// Find Play JAR in lib/
	playJar, version := p.findPlayJar(libDir)
	if playJar == "" {
		return false
	}

	// Parse version - must be 2.2 or higher
	if !p.isPost22Version(version) {
		return false
	}

	// Check for bin/ directory at root (optional)
	binDir := filepath.Join(buildDir, "bin")
	binStat, binErr := os.Stat(binDir)
	if binErr == nil && binStat.IsDir() {
		// Try to find start script in bin/
		startScript := p.findStartScript(binDir)
		if startScript != "" {
			p.startScript = filepath.Join("bin", startScript)
		} else {
			p.startScript = "" // No start script, will need to use java command
		}
	} else {
		p.startScript = "" // No bin/ directory, will need to use java command
	}

	p.playType = "post22_staged"
	p.playVersion = version
	p.libDir = libDir
	p.context.Log.Debug("Detected Play Framework %s (Post22Staged)", version)
	return true
}

// detectPre22Dist detects Play 2.0-2.1 distributed applications
// Structure: application-root/start, application-root/lib/play_*.jar
func (p *PlayContainer) detectPre22Dist(buildDir string) bool {
	// Check for application-root/ directory
	appRoot := filepath.Join(buildDir, "application-root")
	appRootStat, err := os.Stat(appRoot)
	if err != nil || !appRootStat.IsDir() {
		return false
	}

	// Check for start script
	startScript := filepath.Join(appRoot, "start")
	if _, err := os.Stat(startScript); err != nil {
		return false
	}

	// Check for lib/ directory
	libDir := filepath.Join(appRoot, "lib")
	libStat, libErr := os.Stat(libDir)
	if libErr != nil || !libStat.IsDir() {
		return false
	}

	// Find Play JAR (play.play_*.jar or play_*.jar)
	playJar, version := p.findPlayJar(libDir)
	if playJar == "" {
		return false
	}

	// Version should be 2.0 or 2.1
	if p.isPost22Version(version) {
		return false
	}

	p.playType = "pre22_dist"
	p.playVersion = version
	p.startScript = filepath.Join("application-root", "start")
	p.libDir = libDir
	p.context.Log.Debug("Detected Play Framework %s (Pre22Dist)", version)
	return true
}

// detectPre22Staged detects Play 2.0-2.1 staged applications
// Structure: staged/play_*.jar (may or may not have start script)
func (p *PlayContainer) detectPre22Staged(buildDir string) bool {
	// Check for staged/ directory
	stagedDir := filepath.Join(buildDir, "staged")
	p.context.Log.Debug("Play Pre22Staged: Checking for staged dir: %s", stagedDir)
	stagedStat, err := os.Stat(stagedDir)
	if err != nil || !stagedStat.IsDir() {
		p.context.Log.Debug("Play Pre22Staged: Staged dir not found or not a directory: %v", err)
		return false
	}
	p.context.Log.Debug("Play Pre22Staged: Staged dir found")

	// Find Play JAR in staged/
	playJar, version := p.findPlayJar(stagedDir)
	p.context.Log.Debug("Play Pre22Staged: findPlayJar returned jar=%s, version=%s", playJar, version)
	if playJar == "" {
		p.context.Log.Debug("Play Pre22Staged: No Play JAR found")
		return false
	}

	// Version should be 2.0 or 2.1
	if p.isPost22Version(version) {
		p.context.Log.Debug("Play Pre22Staged: Version %s is Post22, not Pre22", version)
		return false
	}

	// Check if there's a start script (optional)
	startScript := filepath.Join(buildDir, "start")
	p.context.Log.Debug("Play Pre22Staged: Checking for start script: %s", startScript)
	if _, err := os.Stat(startScript); err == nil {
		p.context.Log.Debug("Play Pre22Staged: Start script found")
		p.startScript = "start"
	} else {
		p.context.Log.Debug("Play Pre22Staged: Start script not found, will use java command")
		p.startScript = "" // No start script, will need to use java command
	}

	p.playType = "pre22_staged"
	p.playVersion = version
	p.libDir = stagedDir
	p.context.Log.Debug("Detected Play Framework %s (Pre22Staged)", version)
	return true
}

// findPlayJar finds the Play Framework JAR and extracts version
// Returns jar filename and version string
func (p *PlayContainer) findPlayJar(libDir string) (string, string) {
	entries, err := os.ReadDir(libDir)
	if err != nil {
		return "", ""
	}

	// Match patterns:
	// - com.typesafe.play.play_2.10-2.2.0.jar (Play 2.2+)
	// - play.play_2.9.1-2.0.jar (Play 2.0)
	// - play_2.10-2.1.4.jar (Play 2.1)
	playJarPattern := regexp.MustCompile(`^(?:com\.typesafe\.)?play(?:\.play)?_.*-(.+)\.jar$`)

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		name := entry.Name()
		if matches := playJarPattern.FindStringSubmatch(name); matches != nil {
			version := matches[1]
			p.context.Log.Debug("Found Play JAR: %s (version: %s)", name, version)
			return name, version
		}
	}

	return "", ""
}

// findStartScript finds a non-.bat startup script in the given directory
func (p *PlayContainer) findStartScript(binDir string) string {
	entries, err := os.ReadDir(binDir)
	if err != nil {
		return ""
	}

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		// Skip .bat files
		if filepath.Ext(name) != ".bat" {
			return name
		}
	}

	return ""
}

// isPost22Version checks if version is 2.2 or higher
func (p *PlayContainer) isPost22Version(version string) bool {
	// Parse major.minor version
	parts := strings.Split(version, ".")
	if len(parts) < 2 {
		return false
	}

	major := parts[0]
	minor := parts[1]

	// Check for 2.2+
	if major == "2" {
		// Extract numeric minor version
		minorInt := 0
		fmt.Sscanf(minor, "%d", &minorInt)
		return minorInt >= 2
	}

	// Version 3+ would also be post-2.2
	majorInt := 0
	fmt.Sscanf(major, "%d", &majorInt)
	return majorInt > 2
}

// Supply installs and configures the Play Framework application
func (p *PlayContainer) Supply() error {
	p.context.Log.BeginStep("Installing Play Framework %s (%s)", p.playVersion, p.playType)

	// Make start script executable
	if err := p.makeStartScriptExecutable(); err != nil {
		return fmt.Errorf("failed to make start script executable: %w", err)
	}

	p.context.Log.Info("Play Framework %s installation complete", p.playVersion)
	return nil
}

// makeStartScriptExecutable ensures the start script has execute permissions
func (p *PlayContainer) makeStartScriptExecutable() error {
	buildDir := p.context.Stager.BuildDir()
	scriptPath := filepath.Join(buildDir, p.startScript)

	if err := os.Chmod(scriptPath, 0755); err != nil {
		p.context.Log.Warning("Could not make %s executable: %s", p.startScript, err.Error())
		return err
	}

	p.context.Log.Debug("Made %s executable", p.startScript)
	return nil
}

// Finalize performs final configuration for the Play Framework application
func (p *PlayContainer) Finalize() error {
	p.context.Log.BeginStep("Finalizing Play Framework %s", p.playVersion)

	// Collect additional libraries (JVMKill agent, frameworks, etc.)
	additionalLibs := p.collectAdditionalLibraries()
	p.context.Log.Info("Found %d additional libraries for CLASSPATH", len(additionalLibs))

	// Build CLASSPATH from additional libraries
	// Convert staging paths to runtime paths
	classpathParts := p.buildRuntimeClasspath(additionalLibs)

	// Determine the script directory based on Play type
	var scriptDir string
	switch p.playType {
	case "post22_dist":
		scriptDir = "application-root/bin"
	case "post22_staged":
		scriptDir = "bin"
	case "pre22_dist":
		scriptDir = "application-root"
	case "pre22_staged":
		scriptDir = "."
	default:
		scriptDir = "bin"
	}

	// Write profile.d script that sets up environment variables
	// This follows the immutable BuildDir pattern: configure via environment, don't modify files
	envContent := fmt.Sprintf(`export DEPS_DIR=${DEPS_DIR:-/home/vcap/deps}
export PLAY_HOME=$HOME
export PLAY_BIN=$HOME/%s
export PATH=$PLAY_BIN:$PATH

# Prepend additional libraries to CLASSPATH
# Play start scripts respect CLASSPATH environment variable
# This includes JVMKill agent, framework JARs, JDBC drivers, etc.
`, scriptDir)

	// Add CLASSPATH if we have additional libraries
	if len(classpathParts) > 0 {
		classpathValue := strings.Join(classpathParts, ":")
		envContent += fmt.Sprintf("export CLASSPATH=\"%s:${CLASSPATH:-}\"\n", classpathValue)
		p.context.Log.Info("Configured CLASSPATH with %d additional libraries", len(classpathParts))
	}

	if err := p.context.Stager.WriteProfileD("play.sh", envContent); err != nil {
		p.context.Log.Warning("Could not write play.sh profile.d script: %s", err.Error())
	} else {
		p.context.Log.Debug("Created profile.d script: play.sh")
	}

	// Configure JAVA_OPTS to be picked up by Play startup scripts
	// Play uses -Dhttp.port system property to configure the HTTP port
	// Note: JVMKill agent is configured by the JRE component via .profile.d/java_opts.sh
	javaOpts := []string{
		"-Dhttp.port=$PORT",
		"-Djava.io.tmpdir=$TMPDIR",
		"-XX:+ExitOnOutOfMemoryError",
	}

	// Play start scripts respect JAVA_OPTS environment variable
	// Write JAVA_OPTS for the startup script to use
	if err := p.context.Stager.WriteEnvFile("JAVA_OPTS",
		strings.Join(javaOpts, " ")); err != nil {
		return fmt.Errorf("failed to write JAVA_OPTS: %w", err)
	}

	p.context.Log.Info("Play Framework finalization complete (using environment variables, not modifying scripts)")
	return nil
}

// collectAdditionalLibraries gathers all additional libraries that should be added to CLASSPATH
// This includes framework-provided JAR libraries installed during supply phase
func (p *PlayContainer) collectAdditionalLibraries() []string {
	var libs []string
	depsDir := p.context.Stager.DepDir()

	// Scan $DEPS_DIR/0/ for all framework directories
	entries, err := os.ReadDir(depsDir)
	if err != nil {
		p.context.Log.Debug("Unable to read deps directory: %s", err.Error())
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
			p.context.Log.Debug("Error globbing JARs in %s: %s", frameworkDir, err.Error())
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

// buildRuntimeClasspath converts staging-time library paths to runtime paths
// At staging time, libraries are in $DEPS_DIR/0/<framework>/*.jar
// At runtime, they'll be in /home/vcap/deps/0/<framework>/*.jar
func (p *PlayContainer) buildRuntimeClasspath(libs []string) []string {
	var classpathParts []string
	depsDir := p.context.Stager.DepDir()
	buildDir := p.context.Stager.BuildDir()

	for _, lib := range libs {
		var runtimePath string

		// Check if library is in deps directory
		if strings.HasPrefix(lib, depsDir) {
			// Convert to runtime $DEPS_DIR path
			relPath, err := filepath.Rel(depsDir, lib)
			if err != nil {
				p.context.Log.Warning("Could not calculate relative path for %s: %s", lib, err.Error())
				continue
			}
			relPath = filepath.ToSlash(relPath)
			runtimePath = fmt.Sprintf("$DEPS_DIR/%s", relPath)
		} else if strings.HasPrefix(lib, buildDir) {
			// Convert to runtime $HOME path
			relPath, err := filepath.Rel(buildDir, lib)
			if err != nil {
				p.context.Log.Warning("Could not calculate relative path for %s: %s", lib, err.Error())
				continue
			}
			relPath = filepath.ToSlash(relPath)
			runtimePath = fmt.Sprintf("$HOME/%s", relPath)
		} else {
			// Fallback: library path doesn't match expected patterns
			p.context.Log.Warning("Library path %s doesn't match deps or build directory, using as-is", lib)
			runtimePath = lib
		}

		classpathParts = append(classpathParts, runtimePath)
	}

	return classpathParts
}

// Release returns the command to start the Play Framework application
func (p *PlayContainer) Release() (string, error) {
	// Check if Detect() was called successfully
	if p.playType == "" {
		return "", fmt.Errorf("no Play application detected, Detect() must be called first")
	}

	// Play Framework start command varies by type
	var cmd string

	// If we have a start script, use it
	if p.startScript != "" {
		// Use absolute path with $HOME prefix to ensure the script can be found at runtime
		// Cloud Foundry sets $HOME to the application root directory
		cmd = fmt.Sprintf("$HOME/%s", p.startScript)
	} else {
		// No start script - use java command with NettyServer
		// This is for staged apps without start scripts
		libPath := filepath.ToSlash(p.libDir)
		// For staged apps, libDir is relative to buildDir, convert to $HOME
		if p.playType == "pre22_staged" || p.playType == "post22_staged" {
			relPath, err := filepath.Rel(p.context.Stager.BuildDir(), p.libDir)
			if err == nil {
				libPath = filepath.ToSlash(relPath)
			}
		}
		// Use eval to properly handle backslash-escaped values in $JAVA_OPTS (Ruby buildpack parity)
		cmd = fmt.Sprintf("eval exec java $JAVA_OPTS -cp $HOME/%s/* play.core.server.NettyServer $HOME", libPath)
	}

	p.context.Log.Debug("Play Framework release command: %s", cmd)
	return cmd, nil
}

// Validate checks for ambiguous Play configurations
// This should be called during detection to reject hybrid apps
func (p *PlayContainer) Validate() error {
	buildDir := p.context.Stager.BuildDir()

	// Check for ambiguous Play 2.1/2.2 hybrid configurations
	// This happens when both Pre22 and Post22 structures exist

	detected := []string{}

	if p.detectPost22Dist(buildDir) {
		detected = append(detected, "Post22Dist")
	}
	if p.detectPost22Staged(buildDir) {
		detected = append(detected, "Post22Staged")
	}
	if p.detectPre22Dist(buildDir) {
		detected = append(detected, "Pre22Dist")
	}
	if p.detectPre22Staged(buildDir) {
		detected = append(detected, "Pre22Staged")
	}

	if len(detected) > 1 {
		return fmt.Errorf("Play Framework application version cannot be determined: %v", detected)
	}

	return nil
}
