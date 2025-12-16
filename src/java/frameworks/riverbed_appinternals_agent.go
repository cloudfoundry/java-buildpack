// Cloud Foundry Java Buildpack
// Copyright 2013-2021 the original author or authors.
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
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// RiverbedAppInternalsAgentFramework represents the Riverbed AppInternals agent framework
type RiverbedAppInternalsAgentFramework struct {
	context   *Context
	agentPath string
}

// NewRiverbedAppInternalsAgentFramework creates a new Riverbed AppInternals agent framework instance
func NewRiverbedAppInternalsAgentFramework(ctx *Context) *RiverbedAppInternalsAgentFramework {
	return &RiverbedAppInternalsAgentFramework{context: ctx}
}

// Detect checks if Riverbed AppInternals agent should be enabled
func (r *RiverbedAppInternalsAgentFramework) Detect() (string, error) {
	// Check for riverbed-appinternals service binding
	if r.hasServiceBinding() {
		r.context.Log.Debug("Riverbed AppInternals agent framework detected via service binding")
		return "riverbed-appinternals-agent", nil
	}

	r.context.Log.Debug("Riverbed AppInternals agent: no service binding found")
	return "", nil
}

// Supply downloads and installs the Riverbed AppInternals agent
func (r *RiverbedAppInternalsAgentFramework) Supply() error {
	r.context.Log.BeginStep("Installing Riverbed AppInternals agent")

	// Get dependency from manifest
	dep, err := r.context.Manifest.DefaultVersion("riverbed-appinternals-agent")
	if err != nil {
		return fmt.Errorf("unable to find Riverbed AppInternals agent in manifest: %w", err)
	}

	// Install the agent
	agentDir := filepath.Join(r.context.Stager.DepDir(), "riverbed_appinternals_agent")
	if err := r.context.Installer.InstallDependency(dep, agentDir); err != nil {
		return fmt.Errorf("failed to install Riverbed AppInternals agent: %w", err)
	}

	// Find the installed agent directory (contains lib/rvbd-agent.jar)
	agentJarPath := filepath.Join(agentDir, "lib", "rvbd-agent.jar")
	if _, err := os.Stat(agentJarPath); err != nil {
		return fmt.Errorf("Riverbed AppInternals agent JAR not found after installation: %w", err)
	}
	r.agentPath = agentJarPath

	r.context.Log.Info("Riverbed AppInternals agent %s installed", dep.Version)
	return nil
}

// Finalize configures the Riverbed AppInternals agent
func (r *RiverbedAppInternalsAgentFramework) Finalize() error {
	if r.agentPath == "" {
		return nil
	}

	r.context.Log.BeginStep("Configuring Riverbed AppInternals agent")

	// Convert staging path to runtime path
	relPath, err := filepath.Rel(r.context.Stager.DepDir(), r.agentPath)
	if err != nil {
		return fmt.Errorf("failed to determine relative path for Riverbed AppInternals agent: %w", err)
	}
	runtimeJarPath := filepath.Join("$DEPS_DIR/0", relPath)

	// Get credentials from service binding
	credentials := r.getCredentials()

	// Build all JAVA_OPTS options
	var opts []string
	opts = append(opts, fmt.Sprintf("-javaagent:%s", runtimeJarPath))

	// Configure moniker (application name)
	moniker := credentials.Moniker
	if moniker == "" {
		moniker = r.getApplicationName()
	}
	if moniker != "" {
		opts = append(opts, fmt.Sprintf("-Drvbd.moniker=%s", moniker))
	}

	// Configure analysis server
	if credentials.AnalysisServer != "" {
		opts = append(opts, fmt.Sprintf("-Drvbd.analysis.server=%s", credentials.AnalysisServer))
	}

	// Write all options to .opts file
	javaOpts := strings.Join(opts, " ")
	if err := writeJavaOptsFile(r.context, 37, "riverbed_appinternals_agent", javaOpts); err != nil {
		return fmt.Errorf("failed to write JAVA_OPTS for Riverbed AppInternals: %w", err)
	}

	r.context.Log.Info("Riverbed AppInternals agent configured")
	return nil
}

// hasServiceBinding checks if there's a riverbed-appinternals service binding
func (r *RiverbedAppInternalsAgentFramework) hasServiceBinding() bool {
	vcapServices, err := GetVCAPServices()
	if err != nil {
		r.context.Log.Debug("Failed to parse VCAP_SERVICES: %s", err.Error())
		return false
	}

	// Check for Riverbed AppInternals service binding via multiple methods
	if vcapServices.HasService("riverbed-appinternals") ||
		vcapServices.HasService("appinternals") ||
		vcapServices.HasTag("riverbed") ||
		vcapServices.HasTag("appinternals") ||
		vcapServices.HasServiceByNamePattern("riverbed") ||
		vcapServices.HasServiceByNamePattern("appinternals") {
		return true
	}

	return false
}

// RiverbedCredentials holds Riverbed AppInternals credentials
type RiverbedCredentials struct {
	Moniker        string
	AnalysisServer string
}

// getCredentials retrieves Riverbed credentials from service binding
func (r *RiverbedAppInternalsAgentFramework) getCredentials() RiverbedCredentials {
	creds := RiverbedCredentials{}

	vcapServices, err := GetVCAPServices()
	if err != nil {
		return creds
	}

	// Try to find service by exact label first
	var service *VCAPService
	if svc := vcapServices.GetService("riverbed-appinternals"); svc != nil {
		service = svc
	} else if svc := vcapServices.GetService("appinternals"); svc != nil {
		service = svc
	} else {
		// Fall back to pattern matching for user-provided services
		service = vcapServices.GetServiceByNamePattern("riverbed")
		if service == nil {
			service = vcapServices.GetServiceByNamePattern("appinternals")
		}
	}

	if service == nil {
		return creds
	}

	// Extract moniker (application name) - try multiple key variations
	if moniker, ok := service.Credentials["moniker"].(string); ok {
		creds.Moniker = moniker
	} else if moniker, ok := service.Credentials["rvbd_moniker"].(string); ok {
		creds.Moniker = moniker
	}

	// Extract analysis server - try multiple key variations
	if server, ok := service.Credentials["analysis_server"].(string); ok {
		creds.AnalysisServer = server
	} else if server, ok := service.Credentials["analysisServer"].(string); ok {
		creds.AnalysisServer = server
	} else if server, ok := service.Credentials["rvbd_analysis_server"].(string); ok {
		creds.AnalysisServer = server
	}

	return creds
}

// getApplicationName returns the application name from VCAP_APPLICATION
func (r *RiverbedAppInternalsAgentFramework) getApplicationName() string {
	vcapApp := os.Getenv("VCAP_APPLICATION")
	if vcapApp == "" {
		return ""
	}

	var appData map[string]interface{}
	if err := json.Unmarshal([]byte(vcapApp), &appData); err != nil {
		return ""
	}

	if name, ok := appData["application_name"].(string); ok {
		return name
	}

	return ""
}

