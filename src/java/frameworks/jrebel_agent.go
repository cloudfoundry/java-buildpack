package frameworks

import (
	"fmt"
	"os"
	"path/filepath"
)

// JRebelAgentFramework represents the JRebel Agent framework
type JRebelAgentFramework struct {
	context      *Context
	agentLibPath string
}

// NewJRebelAgentFramework creates a new instance of JRebelAgentFramework
func NewJRebelAgentFramework(ctx *Context) *JRebelAgentFramework {
	return &JRebelAgentFramework{context: ctx}
}

// Detect determines if JRebel configuration exists in the application
func (j *JRebelAgentFramework) Detect() (string, error) {
	// Check for rebel-remote.xml configuration file in the app
	rebelRemoteXML := filepath.Join(j.context.Stager.BuildDir(), "rebel-remote.xml")
	if _, err := os.Stat(rebelRemoteXML); err == nil {
		j.context.Log.Info("JRebel configuration detected: rebel-remote.xml")
		return "jrebel", nil
	}

	// Also check in WEB-INF directory for web apps
	webInfRebelXML := filepath.Join(j.context.Stager.BuildDir(), "WEB-INF", "rebel-remote.xml")
	if _, err := os.Stat(webInfRebelXML); err == nil {
		j.context.Log.Info("JRebel configuration detected: WEB-INF/rebel-remote.xml")
		return "jrebel", nil
	}

	return "", nil
}

// Supply downloads and installs the JRebel agent
func (j *JRebelAgentFramework) Supply() error {
	j.context.Log.Info("Installing JRebel Agent")

	dep, err := j.context.Manifest.DefaultVersion("jrebel")
	if err != nil {
		return fmt.Errorf("failed to get jrebel dependency: %w", err)
	}

	frameworkDir := filepath.Join(j.context.Stager.DepDir(), "jrebel")
	if err := os.MkdirAll(frameworkDir, 0755); err != nil {
		return fmt.Errorf("failed to create jrebel directory: %w", err)
	}

	// Download JRebel ZIP
	if err := j.context.Installer.InstallDependency(dep, frameworkDir); err != nil {
		return fmt.Errorf("failed to install jrebel agent: %w", err)
	}

	// Find libjrebel64.so in the extracted files
	// The ZIP contains a nested jrebel/ directory structure
	j.agentLibPath = filepath.Join(frameworkDir, "jrebel", "lib", "libjrebel64.so")
	if _, err := os.Stat(j.agentLibPath); err != nil {
		// Try flat path (older versions)
		j.agentLibPath = filepath.Join(frameworkDir, "lib", "libjrebel64.so")
		if _, err := os.Stat(j.agentLibPath); err != nil {
			j.agentLibPath = filepath.Join(frameworkDir, "libjrebel64.so")
		}
	}

	j.context.Log.Info("JRebel Agent installed successfully")
	return nil
}

// Finalize configures the JRebel agent for runtime
func (j *JRebelAgentFramework) Finalize() error {
	j.context.Log.Info("Configuring JRebel Agent")

	// Reconstruct path if not set (separate finalize instance)
	if j.agentLibPath == "" {
		frameworkDir := filepath.Join(j.context.Stager.DepDir(), "jrebel")
		// Try nested path first (current versions)
		j.agentLibPath = filepath.Join(frameworkDir, "jrebel", "lib", "libjrebel64.so")
		if _, err := os.Stat(j.agentLibPath); err != nil {
			// Try flat path (older versions)
			j.agentLibPath = filepath.Join(frameworkDir, "lib", "libjrebel64.so")
			if _, err := os.Stat(j.agentLibPath); err != nil {
				j.agentLibPath = filepath.Join(frameworkDir, "libjrebel64.so")
			}
		}
	}

	// Verify agent library exists at staging time
	if _, err := os.Stat(j.agentLibPath); err != nil {
		j.context.Log.Warning("JRebel agent library not found: %s", j.agentLibPath)
		return nil
	}

	// Convert staging path to runtime path using $DEPS_DIR
	// Extract the relative path from the absolute staging path
	frameworkDir := filepath.Join(j.context.Stager.DepDir(), "jrebel")
	relPath, err := filepath.Rel(frameworkDir, j.agentLibPath)
	if err != nil {
		j.context.Log.Warning("Failed to determine relative path for JRebel agent: %s", err)
		return nil
	}
	runtimeAgentPath := fmt.Sprintf("$DEPS_DIR/0/jrebel/%s", relPath)

	// Write JAVA_OPTS to .opts file with priority 31 (Ruby buildpack line 65)
	// This ensures JRebel runs AFTER Container Security Provider (priority 17)
	javaOpts := fmt.Sprintf("-agentpath:%s", runtimeAgentPath)
	if err := writeJavaOptsFile(j.context, 31, "jrebel", javaOpts); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	j.context.Log.Info("JRebel Agent configured successfully (priority 31)")
	return nil
}
