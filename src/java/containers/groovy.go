package containers

import (
	"fmt"
	"os"
	"path/filepath"
)

// GroovyContainer handles Groovy script applications
type GroovyContainer struct {
	context       *Context
	groovyScripts []string
}

// NewGroovyContainer creates a new Groovy container
func NewGroovyContainer(ctx *Context) *GroovyContainer {
	return &GroovyContainer{
		context: ctx,
	}
}

// Detect checks if this is a Groovy application
func (g *GroovyContainer) Detect() (string, error) {
	buildDir := g.context.Stager.BuildDir()

	// Look for .groovy files
	groovyFiles, err := filepath.Glob(filepath.Join(buildDir, "*.groovy"))
	if err != nil {
		return "", err
	}

	if len(groovyFiles) > 0 {
		g.groovyScripts = groovyFiles
		g.context.Log.Debug("Detected Groovy application with %d script(s)", len(groovyFiles))
		return "Groovy", nil
	}

	return "", nil
}

// Supply installs Groovy and dependencies
func (g *GroovyContainer) Supply() error {
	g.context.Log.BeginStep("Supplying Groovy")

	// Install Groovy runtime
	dep, err := g.context.Manifest.DefaultVersion("groovy")
	if err != nil {
		g.context.Log.Warning("Unable to determine default Groovy version")
		// Fallback version
		dep.Name = "groovy"
		dep.Version = "4.0.0"
	}

	// Install Groovy with strip components to remove the top-level directory
	// Groovy archives (e.g., apache-groovy-binary-4.0.23.zip) extract to groovy-X.Y.Z/ subdirectory
	groovyDir := filepath.Join(g.context.Stager.DepDir(), "groovy")
	if err := g.context.Installer.InstallDependencyWithStrip(dep, groovyDir, 1); err != nil {
		return fmt.Errorf("failed to install Groovy: %w", err)
	}

	g.context.Log.Info("Installed Groovy version %s", dep.Version)

	// Write profile.d script to set GROOVY_HOME at runtime
	depsIdx := g.context.Stager.DepsIdx()
	groovyPath := fmt.Sprintf("$DEPS_DIR/%s/groovy", depsIdx)

	envContent := fmt.Sprintf("export GROOVY_HOME=%s\n", groovyPath)
	if err := g.context.Stager.WriteProfileD("groovy.sh", envContent); err != nil {
		g.context.Log.Warning("Could not write groovy.sh profile.d script: %s", err.Error())
	} else {
		g.context.Log.Debug("Created profile.d script: groovy.sh")
	}

	// Note: JVMKill agent is installed by the JRE component (src/java/jres/jvmkill.go)
	// No need to install it here to avoid duplication

	return nil
}

// Finalize performs final Groovy configuration
func (g *GroovyContainer) Finalize() error {
	g.context.Log.BeginStep("Finalizing Groovy")

	// Note: JAVA_OPTS (including JVMKill agent) is configured by the JRE component
	// via profile.d/java_opts.sh. No need to configure it here to avoid duplication.

	return nil
}

// Release returns the Groovy startup command
func (g *GroovyContainer) Release() (string, error) {
	// Determine which script to run
	var mainScript string

	// Check for GROOVY_SCRIPT environment variable
	mainScript = os.Getenv("GROOVY_SCRIPT")

	if mainScript == "" && len(g.groovyScripts) > 0 {
		// Use Ruby buildpack logic to find the main script:
		// 1. Files with static void main() method
		// 2. Non-POGO files (simple scripts without class definitions)
		// 3. Files with shebang
		// Returns the single candidate if exactly one matches
		selectedScript, err := FindMainGroovyScript(g.groovyScripts)
		if err != nil {
			g.context.Log.Warning("Error finding main Groovy script: %s", err.Error())
		}
		if selectedScript != "" {
			mainScript = filepath.Base(selectedScript)
			g.context.Log.Debug("Selected main script: %s", mainScript)
		} else {
			// Fall back to the first script if no clear candidate
			mainScript = filepath.Base(g.groovyScripts[0])
			g.context.Log.Debug("Using first script: %s", mainScript)
		}
	}

	if mainScript == "" {
		return "", fmt.Errorf("no Groovy script specified (set GROOVY_SCRIPT)")
	}

	// Note: JAVA_OPTS is set via environment variables (profile.d/java_opts.sh)
	// The groovy command reads JAVA_OPTS from the environment, not command-line args
	cmd := fmt.Sprintf("$GROOVY_HOME/bin/groovy %s", mainScript)
	return cmd, nil
}
