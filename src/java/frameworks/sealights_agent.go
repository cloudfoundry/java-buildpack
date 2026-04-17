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

// SealightsAgentFramework represents the Sealights agent framework
type SealightsAgentFramework struct {
	context *common.Context
}

// NewSealightsAgentFramework creates a new SealightsAgentFramework instance
func NewSealightsAgentFramework(ctx *common.Context) *SealightsAgentFramework {
	return &SealightsAgentFramework{context: ctx}
}

// Detect returns the framework name if a Sealights service is bound
func (f *SealightsAgentFramework) Detect() (string, error) {
	vcapServices, err := GetVCAPServices()
	if err != nil {
		return "", nil // Service binding is optional
	}

	// Check for service binding with 'token' credential
	if vcapServices.HasService("sealights") ||
		vcapServices.HasTag("sealights") ||
		vcapServices.HasServiceByNamePattern("sealights") {
		return "Sealights Agent", nil
	}

	return "", nil
}

// Supply downloads and installs the Sealights agent
func (f *SealightsAgentFramework) Supply() error {
	f.context.Log.Debug("Sealights Agent Supply phase")

	// Get version from manifest
	dep := libbuildpack.Dependency{Name: "sealights-agent", Version: ""}
	version, err := f.context.Manifest.DefaultVersion(dep.Name)
	if err != nil {
		return fmt.Errorf("failed to get default version for sealights-agent: %w", err)
	}
	dep.Version = version.Version

	// Install directory
	installDir := filepath.Join(f.context.Stager.DepDir(), "sealights_agent")

	f.context.Log.BeginStep("Installing Sealights Agent %s", dep.Version)

	// Download and extract ZIP with JAR agent
	if err := f.context.Installer.InstallDependency(dep, installDir); err != nil {
		return fmt.Errorf("failed to install sealights-agent: %w", err)
	}

	f.context.Log.Info("Sealights Agent installed successfully")
	return nil
}

// Finalize configures the Sealights agent runtime environment
func (f *SealightsAgentFramework) Finalize() error {
	f.context.Log.Debug("Sealights Agent Finalize phase")

	installDir := filepath.Join(f.context.Stager.DepDir(), "sealights_agent")

	// Find the JAR agent (sl-test-listener.jar or sl-test-listener-*.jar)
	// NOTE: There are multiple Sealights JARs (sl-build-scanner, sl-test-listener, etc.)
	// We need the test-listener for runtime agent support
	agentPath := filepath.Join(installDir, "sl-test-listener.jar")

	// Verify agent exists
	if _, err := os.Stat(agentPath); err != nil {
		f.context.Log.Warning("Sealights agent not found at exact path %s, searching for versioned file", agentPath)
		// Try to find sl-test-listener-*.jar (versioned)
		matches, _ := filepath.Glob(filepath.Join(installDir, "sl-test-listener*.jar"))
		if len(matches) > 0 {
			agentPath = matches[0]
			f.context.Log.Debug("Found Sealights test-listener: %s", agentPath)
		} else {
			// Fallback: search recursively for any sl-test-listener*.jar
			filepath.Walk(installDir, func(path string, info os.FileInfo, err error) error {
				if err != nil {
					return nil
				}
				baseName := filepath.Base(path)
				if !info.IsDir() && (baseName == "sl-test-listener.jar" ||
					(filepath.HasPrefix(baseName, "sl-test-listener") && filepath.Ext(baseName) == ".jar")) {
					agentPath = path
					return filepath.SkipAll
				}
				return nil
			})

			if _, err := os.Stat(agentPath); err != nil {
				return fmt.Errorf("sealights test-listener JAR not found in %s: %w", installDir, err)
			}
		}
	}

	// Get buildpack index for multi-buildpack support
	depsIdx := f.context.Stager.DepsIdx()

	// Convert staging path to runtime path
	relPath, err := filepath.Rel(f.context.Stager.DepDir(), agentPath)
	if err != nil {
		return fmt.Errorf("failed to compute relative path: %w", err)
	}
	runtimeAgentPath := filepath.Join(fmt.Sprintf("$DEPS_DIR/%s", depsIdx), relPath)

	// Get service credentials
	vcapServices, err := GetVCAPServices()
	if err != nil {
		return fmt.Errorf("failed to parse VCAP_SERVICES: %w", err)
	}

	// Find Sealights service
	var service *VCAPService
	if svc := vcapServices.GetService("sealights"); svc != nil {
		service = svc
	} else {
		service = vcapServices.GetServiceByNamePattern("sealights")
	}

	if service == nil {
		return fmt.Errorf("sealights service not found in VCAP_SERVICES")
	}

	// Extract token from credentials
	token, ok := service.Credentials["token"].(string)
	if !ok || token == "" {
		return fmt.Errorf("sealights service missing 'token' credential")
	}

	// Build system properties for Sealights
	// Required: sl.token
	// Optional: sl.tags, sl.enableUpgrade, sl.log.level, sl.log.folder
	systemProps := fmt.Sprintf("-Dsl.token=%s", token)

	// Add optional properties from service credentials
	if tags, ok := service.Credentials["tags"].(string); ok && tags != "" {
		systemProps += fmt.Sprintf(" -Dsl.tags=%s", tags)
	}
	if enableUpgrade, ok := service.Credentials["enableUpgrade"].(string); ok && enableUpgrade != "" {
		systemProps += fmt.Sprintf(" -Dsl.enableUpgrade=%s", enableUpgrade)
	}
	if logLevel, ok := service.Credentials["logLevel"].(string); ok && logLevel != "" {
		systemProps += fmt.Sprintf(" -Dsl.log.level=%s", logLevel)
	}

	// Set log folder to runtime deps directory
	systemProps += fmt.Sprintf(" -Dsl.log.folder=$DEPS_DIR/%s/sealights_logs", depsIdx)

	// Build javaagent argument
	javaAgent := fmt.Sprintf("-javaagent:%s", runtimeAgentPath)

	// Add if custom config is at place
	config, err := f.loadConfig()
	if err != nil {
		f.context.Log.Warning("Failed to load sealight config: %s", err.Error())
		return nil // Don't fail the build
	}
	if config.BuildSessionId != "" {
		systemProps += fmt.Sprintf(" -Dsl.buildSessionId=%s", config.BuildSessionId)
	}
	if slProxy, ok := service.Credentials["sl.proxy"].(string); ok && slProxy != "" {
		systemProps += fmt.Sprintf(" -Dsl.proxy=%s", slProxy)
	} else {
		if config.Proxy != "" {
			systemProps += fmt.Sprintf(" -Dsl.proxy=%s", config.Proxy)
		}
	}
	if slLabId, ok := service.Credentials["sl.labId"].(string); ok && slLabId != "" {
		systemProps += fmt.Sprintf(" -Dsl.labId=%s", slLabId)
	} else {
		if config.LabId != "" {
			systemProps += fmt.Sprintf(" -Dsl.labId=%s", config.LabId)
		}
	}

	// Combine javaagent and system properties
	javaOpts := fmt.Sprintf("%s %s", javaAgent, systemProps)

	// Write to .opts file using priority 39
	if err := writeJavaOptsFile(f.context, 39, "sealights_agent", javaOpts); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	// Create log directory at staging time
	logFolder := filepath.Join(f.context.Stager.DepDir(), "sealights_logs")
	if err := os.MkdirAll(logFolder, 0755); err != nil {
		return fmt.Errorf("failed to create log directory: %w", err)
	}

	f.context.Log.Info("Sealights Agent configured (priority 39)")
	return nil
}

func (f *SealightsAgentFramework) loadConfig() (*sealightsAgentConfig, error) {
	// initialize default values
	sConfig := sealightsAgentConfig{
		BuildSessionId: "",
		LabId:          "",
		Proxy:          "",
		AutoUpgrade:    false,
	}
	config := os.Getenv("JBP_CONFIG_SEALIGHTS")
	if config != "" {
		yamlHandler := common.YamlHandler{}
		err := yamlHandler.ValidateFields([]byte(config), &sConfig)
		if err != nil {
			f.context.Log.Warning("Unknown user config values: %s", err.Error())
		}
		// overlay JBP_CONFIG_SEALIGHTS over default values
		if err = yamlHandler.Unmarshal([]byte(config), &sConfig); err != nil {
			return nil, fmt.Errorf("failed to parse JBP_CONFIG_SEALIGHTS: %w", err)
		}
	}
	return &sConfig, nil
}

type sealightsAgentConfig struct {
	BuildSessionId string `yaml:"build_session_id"`
	LabId          string `yaml:"lab_id"`
	Proxy          string `yaml:"proxy"`
	AutoUpgrade    bool   `yaml:"auto_upgrade"`
}
