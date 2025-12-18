package jres

import (
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"os"
	"path/filepath"
)

// JVMKillAgent manages the JVMKill agent
// JVMKill is an agent that forcibly terminates the JVM when it is unable to allocate memory or
// throws an OutOfMemoryError.
type JVMKillAgent struct {
	ctx        *common.Context
	jreDir     string
	jreVersion string
	agentPath  string
	version    string
}

// NewJVMKillAgent creates a new JVMKill agent
func NewJVMKillAgent(ctx *common.Context, jreDir, jreVersion string) *JVMKillAgent {
	return &JVMKillAgent{
		ctx:        ctx,
		jreDir:     jreDir,
		jreVersion: jreVersion,
	}
}

// Name returns the component name
func (j *JVMKillAgent) Name() string {
	return "JVMKill Agent"
}

// Supply installs the JVMKill agent
func (j *JVMKillAgent) Supply() error {
	j.ctx.Log.Info("Installing JVMKill Agent")

	// Get JVMKill version from manifest
	dep, err := j.ctx.Manifest.DefaultVersion("jvmkill")
	if err != nil {
		return fmt.Errorf("unable to determine JVMKill version: %w", err)
	}

	j.version = dep.Version
	j.ctx.Log.Debug("JVMKill version: %s", j.version)

	// Install to bin directory
	binDir := filepath.Join(j.jreDir, "bin")
	if err := os.MkdirAll(binDir, 0755); err != nil {
		return fmt.Errorf("failed to create bin directory: %w", err)
	}

	// Final destination for the .so file
	finalPath := filepath.Join(binDir, fmt.Sprintf("jvmkill-%s.so", j.version))

	// Clean up if it already exists (from previous run)
	os.RemoveAll(finalPath)

	// InstallDependency treats the path as a directory and extracts into it
	// For a .so file, we want just the file itself
	// So we install to a directory, then extract the .so file from it
	tempDir := filepath.Join(j.ctx.Stager.DepDir(), "tmp", "jvmkill-install")
	os.RemoveAll(tempDir) // Clean up if exists

	j.ctx.Log.Debug("Installing JVMKill to temp directory: %s", tempDir)
	if err := j.ctx.Installer.InstallDependency(dep, tempDir); err != nil {
		return fmt.Errorf("failed to install JVMKill agent: %w", err)
	}
	j.ctx.Log.Debug("JVMKill installed to: %s", tempDir)

	// The actual .so file will be inside the extracted directory
	// Look for jvmkill-*.so files recursively
	var actualSoFile string
	filepath.Walk(tempDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if !info.IsDir() && filepath.Ext(path) == ".so" {
			actualSoFile = path
			return filepath.SkipAll // Found it, stop walking
		}
		return nil
	})

	if actualSoFile == "" {
		return fmt.Errorf("could not find .so file in %s", tempDir)
	}

	j.ctx.Log.Debug("Found jvmkill .so file at: %s", actualSoFile)

	// Copy the .so file to final location
	data, err := os.ReadFile(actualSoFile)
	if err != nil {
		return fmt.Errorf("failed to read jvmkill agent: %w", err)
	}

	if err := os.WriteFile(finalPath, data, 0755); err != nil {
		return fmt.Errorf("failed to write jvmkill agent: %w", err)
	}

	// Clean up temp directory
	os.RemoveAll(tempDir)

	// Make it executable
	if err := os.Chmod(finalPath, 0755); err != nil {
		return fmt.Errorf("failed to chmod JVMKill agent: %w", err)
	}

	j.agentPath = finalPath
	j.ctx.Log.Info("JVMKill Agent installed to %s", finalPath)

	return nil
}

// detectInstalledAgent checks if JVMKill was previously installed and sets agentPath
func (j *JVMKillAgent) detectInstalledAgent() {
	binDir := filepath.Join(j.jreDir, "bin")

	// Try to find jvmkill-*.so files
	entries, err := os.ReadDir(binDir)
	if err != nil {
		return
	}

	for _, entry := range entries {
		name := entry.Name()
		if filepath.Ext(name) == ".so" && len(name) > 7 && name[:7] == "jvmkill" {
			j.agentPath = filepath.Join(binDir, name)
			j.ctx.Log.Debug("Detected installed JVMKill agent: %s", j.agentPath)
			return
		}
	}
}

// Finalize adds JVMKill to JAVA_OPTS
func (j *JVMKillAgent) Finalize() error {
	// If agentPath not set, try to detect it from previous installation
	if j.agentPath == "" {
		j.detectInstalledAgent()
	}

	if j.agentPath == "" {
		return nil // Not installed
	}

	j.ctx.Log.Info("Configuring JVMKill Agent")
	j.ctx.Log.Debug("JVMKill agent staging path: %s", j.agentPath)

	// Convert absolute staging path to runtime-relative path
	// Staging path: /tmp/contents.../deps/0/jre/bin/jvmkill-1.16.0.so
	// Runtime path: $DEPS_DIR/0/jre/bin/jvmkill-1.16.0.so
	runtimeAgentPath := j.convertToRuntimePath(j.agentPath)
	j.ctx.Log.Debug("JVMKill agent runtime path: %s", runtimeAgentPath)

	// Check if there's a volume service for heap dumps
	heapDumpPath := j.getHeapDumpPath()

	// Build agentpath with options
	// Format: -agentpath:/path/to/jvmkill.so=printHeapHistogram=1,heapDumpPath=/path
	var agentOpt string
	if heapDumpPath != "" {
		agentOpt = fmt.Sprintf("-agentpath:%s=printHeapHistogram=1,heapDumpPath=%s", runtimeAgentPath, heapDumpPath)
		j.ctx.Log.Info("Write terminal heap dumps to %s", heapDumpPath)
	} else {
		agentOpt = fmt.Sprintf("-agentpath:%s=printHeapHistogram=1", runtimeAgentPath)
	}

	j.ctx.Log.Debug("Adding to JAVA_OPTS: %s", agentOpt)

	// Add to JAVA_OPTS
	if err := WriteJavaOpts(j.ctx, agentOpt); err != nil {
		return fmt.Errorf("failed to add JVMKill to JAVA_OPTS: %w", err)
	}

	j.ctx.Log.Info("JVMKill Agent added to JAVA_OPTS")

	return nil
}

// convertToRuntimePath converts absolute staging path to runtime absolute path
// Example: /tmp/contents.../deps/0/jre/bin/jvmkill-1.16.0.so -> /home/vcap/deps/0/jre/bin/jvmkill-1.16.0.so
// Note: We use absolute path instead of $DEPS_DIR because startup scripts run before .profile.d scripts
// are sourced, so $DEPS_DIR is not yet available at runtime.
func (j *JVMKillAgent) convertToRuntimePath(stagingPath string) string {
	// Extract filename and build runtime path
	// We know the structure: <staging-path>/deps/<idx>/jre/bin/jvmkill-VERSION.so
	// Runtime path: /home/vcap/deps/<idx>/jre/bin/jvmkill-VERSION.so

	depsIdx := j.ctx.Stager.DepsIdx()
	filename := filepath.Base(stagingPath)

	// Build absolute runtime path (Cloud Foundry standard location)
	return fmt.Sprintf("/home/vcap/deps/%s/jre/bin/%s", depsIdx, filename)
}

// getHeapDumpPath checks for volume service with heap-dump tag and returns path
func (j *JVMKillAgent) getHeapDumpPath() string {
	// Check VCAP_SERVICES for volume service with heap-dump tag
	vcapServices, err := common.GetVCAPServices()
	if err != nil {
		return ""
	}

	// Look for volume service with "heap-dump" tag
	for _, services := range vcapServices {
		for _, service := range services {
			if service.HasTag("heap-dump") {
				// Extract volume mount path from credentials
				if volumeMounts, ok := service.Credentials["volume_mounts"].([]interface{}); ok && len(volumeMounts) > 0 {
					if mount, ok := volumeMounts[0].(map[string]interface{}); ok {
						if containerDir, ok := mount["container_dir"].(string); ok {
							// Build heap dump path
							// Format: /container/dir/space-id/app-id/instance-index.hprof
							appDetails := j.getAppDetails()
							return filepath.Join(containerDir,
								appDetails.spaceID,
								appDetails.appID,
								"$CF_INSTANCE_INDEX-%FT%T%z-${CF_INSTANCE_GUID:0:8}.hprof")
						}
					}
				}
			}
		}
	}

	return ""
}

// appDetails holds application identification info
type appDetails struct {
	appName   string
	appID     string
	spaceName string
	spaceID   string
}

// getAppDetails extracts application details from environment
func (j *JVMKillAgent) getAppDetails() appDetails {
	// These are set by Cloud Foundry
	return appDetails{
		appName:   os.Getenv("VCAP_APPLICATION_NAME"),
		appID:     os.Getenv("VCAP_APPLICATION_ID"),
		spaceName: os.Getenv("VCAP_APPLICATION_SPACE_NAME"),
		spaceID:   os.Getenv("VCAP_APPLICATION_SPACE_ID"),
	}
}
