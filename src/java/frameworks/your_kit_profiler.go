// Cloud Foundry Java Buildpack
// Copyright 2013-2025 the original author or authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package frameworks

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/libbuildpack"
)

// YourKitProfilerFramework represents the YourKit profiler framework
type YourKitProfilerFramework struct {
	ctx *Context
}

// NewYourKitProfilerFramework creates a new YourKitProfilerFramework instance
func NewYourKitProfilerFramework(ctx *Context) *YourKitProfilerFramework {
	return &YourKitProfilerFramework{ctx: ctx}
}

// Detect returns the framework name if YourKit is explicitly enabled
func (f *YourKitProfilerFramework) Detect() (string, error) {
	// YourKit is disabled by default
	// Check for JBP_CONFIG_YOUR_KIT_PROFILER='{enabled: true}'
	enabled := os.Getenv("JBP_CONFIG_YOUR_KIT_PROFILER")
	if enabled != "" {
		// Simple check - if env var contains "enabled" and "true"
		if containsIgnoreCase(enabled, "enabled") && containsIgnoreCase(enabled, "true") {
			return "YourKit Profiler", nil
		}
	}

	return "", nil
}

// Supply downloads and installs the YourKit profiler native library
func (f *YourKitProfilerFramework) Supply() error {
	f.ctx.Log.Debug("YourKit Profiler Supply phase")

	// Get version from manifest
	dep := libbuildpack.Dependency{Name: "your-kit-profiler", Version: ""}
	version, err := f.ctx.Manifest.DefaultVersion(dep.Name)
	if err != nil {
		return fmt.Errorf("failed to get default version for your-kit-profiler: %w", err)
	}
	dep.Version = version.Version

	// Install directory
	installDir := filepath.Join(f.ctx.Stager.DepDir(), "your_kit_profiler")

	f.ctx.Log.BeginStep("Installing YourKit Profiler %s", dep.Version)

	// Download and extract native library
	if err := f.ctx.Installer.InstallDependency(dep, installDir); err != nil {
		return fmt.Errorf("failed to install your-kit-profiler: %w", err)
	}

	f.ctx.Log.Info("YourKit Profiler installed successfully")
	return nil
}

// findYourKitAgent searches for the YourKit agent library in the install directory
func (f *YourKitProfilerFramework) findYourKitAgent(installDir string) (string, error) {
	// Common paths where the agent might be located after extraction
	possiblePaths := []string{
		// Direct path (if ZIP extracts flat)
		filepath.Join(installDir, "bin", "linux-x86-64", "libyjpagent.so"),
		// Nested directory (YourKit-JavaProfiler-VERSION/bin/linux-x86-64/libyjpagent.so)
		"",
		// Root (unlikely but check anyway)
		filepath.Join(installDir, "libyjpagent.so"),
	}

	// Try predefined paths first
	for _, path := range possiblePaths {
		if path == "" {
			continue
		}
		if _, err := os.Stat(path); err == nil {
			return path, nil
		}
	}

	// Search recursively for nested directories
	var foundPath string
	filepath.Walk(installDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // Continue walking on errors
		}
		if !info.IsDir() && info.Name() == "libyjpagent.so" {
			// Found the agent library
			foundPath = path
			return filepath.SkipAll
		}
		return nil
	})

	if foundPath != "" {
		return foundPath, nil
	}

	return "", fmt.Errorf("yourkit agent libyjpagent.so not found in %s", installDir)
}

// Finalize configures the YourKit profiler runtime environment
func (f *YourKitProfilerFramework) Finalize() error {
	f.ctx.Log.Debug("YourKit Profiler Finalize phase")

	installDir := filepath.Join(f.ctx.Stager.DepDir(), "your_kit_profiler")

	// Find the native library (libyjpagent.so)
	agentPath, err := f.findYourKitAgent(installDir)
	if err != nil {
		return fmt.Errorf("failed to locate yourkit agent: %w", err)
	}
	f.ctx.Log.Debug("Found YourKit agent at: %s", agentPath)

	// Convert staging path to runtime path
	relPath, err := filepath.Rel(f.ctx.Stager.DepDir(), agentPath)
	if err != nil {
		return fmt.Errorf("failed to compute relative path: %w", err)
	}
	runtimeAgentPath := filepath.Join("$DEPS_DIR/0", relPath)

	// Build agent options
	// Default options: dir=<home>/yourkit, logdir=<home>/yourkit, port=10001, sessionname=<space>:<app>
	runtimeHomeDir := "$DEPS_DIR/0/yourkit"

	// Create home directory at staging time
	homeDir := filepath.Join(f.ctx.Stager.DepDir(), "yourkit")
	if err := os.MkdirAll(homeDir, 0755); err != nil {
		return fmt.Errorf("failed to create yourkit directory: %w", err)
	}

	// Get session name from VCAP_APPLICATION (space:app)
	sessionName := "cloudfoundry"

	// Get port from config (default: 10001)
	port := "10001"
	portConfig := os.Getenv("JBP_CONFIG_YOUR_KIT_PROFILER")
	if portConfig != "" && containsIgnoreCase(portConfig, "port") {
		// Simple extraction (would need proper YAML parsing in production)
		// For now, use default
	}

	// Build agent path with options using runtime paths
	agentOptions := fmt.Sprintf("dir=%s,logdir=%s,port=%s,sessionname=%s",
		runtimeHomeDir, runtimeHomeDir, port, sessionName)
	javaAgent := fmt.Sprintf("-agentpath:%s=%s", runtimeAgentPath, agentOptions)

	// Write to .opts file using priority 45
	if err := writeJavaOptsFile(f.ctx, 45, "your_kit_profiler", javaAgent); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	f.ctx.Log.Info("YourKit Profiler configured (priority 45)")
	return nil
}
