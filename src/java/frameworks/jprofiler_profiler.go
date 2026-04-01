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
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/libbuildpack"
)

// JProfilerProfilerFramework represents the JProfiler profiler framework
type JProfilerProfilerFramework struct {
	context *common.Context
}

// NewJProfilerProfilerFramework creates a new JProfilerProfilerFramework instance
func NewJProfilerProfilerFramework(ctx *common.Context) *JProfilerProfilerFramework {
	return &JProfilerProfilerFramework{context: ctx}
}

// Detect returns the framework name if JProfiler is explicitly enabled
func (f *JProfilerProfilerFramework) Detect() (string, error) {
	// JProfiler is disabled by default
	// Check for JBP_CONFIG_JPROFILER_PROFILER='{enabled: true}'
	config, err := f.loadConfig()
	if err != nil {
		f.context.Log.Warning("Failed to load jprofile profiler config: %s", err.Error())
		return "", nil // Don't fail the build
	}
	if config.isEnabled() {
		return "JProfiler Profiler", nil
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

	f.context.Log.Debug("Installing JProfiler Profiler %s", dep.Version)

	// Download and extract tarball
	if err := f.context.Installer.InstallDependency(dep, installDir); err != nil {
		return fmt.Errorf("failed to install jprofiler-profiler: %w", err)
	}

	f.context.Log.Info("JProfiler Profiler installed successfully")
	return nil
}

// findJProfilerAgent searches for the JProfiler agent library in the install directory
func (f *JProfilerProfilerFramework) findJProfilerAgent(installDir string) (string, error) {
	// JProfiler for linux-x64/amd64 (the buildpack target platform)
	// Must filter by architecture to avoid ARM64 version (linux-aarch64)
	return FindFileInDirectoryWithArchFilter(
		installDir,
		"libjprofilerti.so",
		[]string{"bin/linux-x64", "bin/linux-amd64"},
		[]string{"linux-x64", "linux-amd64"},
	)
}

// Finalize configures the JProfiler profiler runtime environment
func (f *JProfilerProfilerFramework) Finalize() error {
	f.context.Log.Debug("JProfiler Profiler Finalize phase")

	// Get buildpack index for multi-buildpack support
	depsIdx := f.context.Stager.DepsIdx()

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
	runtimeAgentPath := filepath.Join(fmt.Sprintf("$DEPS_DIR/%s", depsIdx), relPath)

	config, err := f.loadConfig()
	if err != nil {
		f.context.Log.Warning("Failed to load jprofile profiler config: %s", err.Error())
		return nil // Don't fail the build
	}

	// Build agent options
	// Default options: port=8849, nowait (don't wait for profiler UI to connect)
	port := config.Port
	nowait := config.NoWait
	
	// Build agent path with options
	var agentOptions string
	if nowait {
		agentOptions = fmt.Sprintf("port=%v,%v", port, "nowait")
	} else {
		agentOptions = fmt.Sprintf("port=%v", port)
	}
	javaAgent := fmt.Sprintf("-agentpath:%s=%s", runtimeAgentPath, agentOptions)

	f.context.Log.Info("JProfiler Profiler java agent options: %s", javaAgent)
	// Write to .opts file using priority 30
	if err := writeJavaOptsFile(f.context, 30, "jprofiler_profiler", javaAgent); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	f.context.Log.Info("JProfiler Profiler configured (priority 30)")
	return nil
}

func (f *JProfilerProfilerFramework) loadConfig() (*jProfilerConfig, error) {
	// initialize default values
	jpConfig := jProfilerConfig{
		Enabled: false,
		NoWait:  true,
		Port:    8849,
	}
	config := os.Getenv("JBP_CONFIG_JPROFILER_PROFILER")
	if config != "" {
		yamlHandler := common.YamlHandler{}
		err := yamlHandler.ValidateFields([]byte(config), &jpConfig)
		if err != nil {
			f.context.Log.Warning("Unknown user config values: %s", err.Error())
		}
		// overlay JBP_CONFIG_JPROFILER_PROFILER over default values
		if err = yamlHandler.Unmarshal([]byte(config), &jpConfig); err != nil {
			return nil, fmt.Errorf("failed to parse JBP_CONFIG_JPROFILER_PROFILER: %w", err)
		}
	}
	return &jpConfig, nil
}

type jProfilerConfig struct {
	Enabled bool `yaml:"enabled"`
	NoWait  bool `yaml:"nowait"`
	Port    int  `yaml:"port"`
}

func (j *jProfilerConfig) isEnabled() bool {
	return j.Enabled
}
