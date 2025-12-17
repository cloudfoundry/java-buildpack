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

// JProfilerProfilerFramework represents the JProfiler profiler framework
type JProfilerProfilerFramework struct {
	context *Context
}

// NewJProfilerProfilerFramework creates a new JProfilerProfilerFramework instance
func NewJProfilerProfilerFramework(ctx *Context) *JProfilerProfilerFramework {
	return &JProfilerProfilerFramework{context: ctx}
}

// Detect returns the framework name if JProfiler is explicitly enabled
func (f *JProfilerProfilerFramework) Detect() (string, error) {
	// JProfiler is disabled by default
	// Check for JBP_CONFIG_JPROFILER_PROFILER='{enabled: true}'
	enabled := os.Getenv("JBP_CONFIG_JPROFILER_PROFILER")
	if enabled != "" {
		// Simple check - if env var contains "enabled" and "true"
		if containsIgnoreCase(enabled, "enabled") && containsIgnoreCase(enabled, "true") {
			return "JProfiler Profiler", nil
		}
	}

	return "", nil
}

// Supply downloads and installs the JProfiler profiler
func (f *JProfilerProfilerFramework) Supply() error {
	f.context.Log.Debug("JProfiler Profiler Supply phase")

	// Get version from manifest
	dep := libbuildpack.Dependency{Name: "jprofiler-profiler", Version: ""}
	version, err := f.context.Manifest.DefaultVersion(dep.Name)
	if err != nil {
		return fmt.Errorf("failed to get default version for jprofiler-profiler: %w", err)
	}
	dep.Version = version.Version

	// Install directory
	installDir := filepath.Join(f.context.Stager.DepDir(), "jprofiler_profiler")

	f.context.Log.BeginStep("Installing JProfiler Profiler %s", dep.Version)

	// Download and extract tarball
	if err := f.context.Installer.InstallDependency(dep, installDir); err != nil {
		return fmt.Errorf("failed to install jprofiler-profiler: %w", err)
	}

	f.context.Log.Info("JProfiler Profiler installed successfully")
	return nil
}

// findJProfilerAgent searches for the JProfiler agent library in the install directory
func (f *JProfilerProfilerFramework) findJProfilerAgent(installDir string) (string, error) {
	// Common paths where the agent might be located after extraction
	// JProfiler for linux-x64 (the buildpack target platform)
	possiblePaths := []string{
		// Direct path (flat extraction)
		filepath.Join(installDir, "bin", "linux-x64", "libjprofilerti.so"),
		// Flat root (unlikely but check)
		filepath.Join(installDir, "libjprofilerti.so"),
	}

	// Try predefined paths first
	for _, path := range possiblePaths {
		if _, err := os.Stat(path); err == nil {
			return path, nil
		}
	}

	// Search recursively for nested directories (e.g., jprofiler14.0.5/bin/linux-x64/...)
	var foundPath string
	filepath.Walk(installDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		// Look for libjprofilerti.so in a linux-amd64 directory
		if !info.IsDir() && info.Name() == "libjprofilerti.so" && filepath.Base(filepath.Dir(path)) == "linux-amd64" {
			foundPath = path
			return filepath.SkipAll
		}
		return nil
	})

	if foundPath != "" {
		return foundPath, nil
	}

	return "", fmt.Errorf("jprofiler agent libjprofilerti.so not found in %s", installDir)
}

// Finalize configures the JProfiler profiler runtime environment
func (f *JProfilerProfilerFramework) Finalize() error {
	f.context.Log.Debug("JProfiler Profiler Finalize phase")

	installDir := filepath.Join(f.context.Stager.DepDir(), "jprofiler_profiler")

	// Find the native library (libjprofilerti.so in bin/linux-x64/)
	agentPath, err := f.findJProfilerAgent(installDir)
	if err != nil {
		return fmt.Errorf("failed to locate jprofiler agent: %w", err)
	}
	f.context.Log.Debug("Found JProfiler agent at: %s", agentPath)

	// Convert staging path to runtime path
	relPath, err := filepath.Rel(f.context.Stager.DepDir(), agentPath)
	if err != nil {
		return fmt.Errorf("failed to compute relative path: %w", err)
	}
	runtimeAgentPath := filepath.Join("$DEPS_DIR/0", relPath)

	// Build agent options
	// Default options: port=8849, nowait (don't wait for profiler UI to connect)
	port := "8849"
	portConfig := os.Getenv("JBP_CONFIG_JPROFILER_PROFILER")
	if portConfig != "" && containsIgnoreCase(portConfig, "port") {
		// Simple extraction (would need proper YAML parsing in production)
		// For now, use default
	}

	// Check for nowait option (default: true)
	nowait := "nowait"
	if portConfig != "" && containsIgnoreCase(portConfig, "nowait") && containsIgnoreCase(portConfig, "false") {
		nowait = ""
	}

	// Build agent path with options
	var agentOptions string
	if nowait != "" {
		agentOptions = fmt.Sprintf("port=%s,%s", port, nowait)
	} else {
		agentOptions = fmt.Sprintf("port=%s", port)
	}
	javaAgent := fmt.Sprintf("-agentpath:%s=%s", runtimeAgentPath, agentOptions)

	// Write to .opts file using priority 30
	if err := writeJavaOptsFile(f.context, 30, "jprofiler_profiler", javaAgent); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	f.context.Log.Info("JProfiler Profiler configured (priority 30)")
	return nil
}
