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

// IntroscopeAgentFramework represents the CA APM Introscope agent framework
type IntroscopeAgentFramework struct {
	context   *Context
	agentPath string
}

// NewIntroscopeAgentFramework creates a new Introscope agent framework instance
func NewIntroscopeAgentFramework(ctx *Context) *IntroscopeAgentFramework {
	return &IntroscopeAgentFramework{context: ctx}
}

// Detect checks if Introscope agent should be enabled
func (i *IntroscopeAgentFramework) Detect() (string, error) {
	// Check for introscope service binding
	if i.hasServiceBinding() {
		i.context.Log.Debug("Introscope agent framework detected via service binding")
		return "introscope-agent", nil
	}

	i.context.Log.Debug("Introscope agent: no service binding found")
	return "", nil
}

// Supply downloads and installs the Introscope agent
func (i *IntroscopeAgentFramework) Supply() error {
	i.context.Log.BeginStep("Installing Introscope agent")

	// Get dependency from manifest
	dep, err := i.context.Manifest.DefaultVersion("introscope-agent")
	if err != nil {
		return fmt.Errorf("unable to find Introscope agent in manifest: %w", err)
	}

	// Install the agent
	agentDir := filepath.Join(i.context.Stager.DepDir(), "introscope_agent")
	if err := i.context.Installer.InstallDependency(dep, agentDir); err != nil {
		return fmt.Errorf("failed to install Introscope agent: %w", err)
	}

	// Find the installed agent JAR
	agentPattern := filepath.Join(agentDir, "Agent.jar")
	if _, err := os.Stat(agentPattern); err != nil {
		return fmt.Errorf("Introscope Agent.jar not found after installation: %w", err)
	}
	i.agentPath = agentPattern

	i.context.Log.Info("Introscope agent %s installed", dep.Version)
	return nil
}

// Finalize configures the Introscope agent
func (i *IntroscopeAgentFramework) Finalize() error {
	if i.agentPath == "" {
		return nil
	}

	i.context.Log.BeginStep("Configuring Introscope agent")

	// Convert staging path to runtime path
	relPath, err := filepath.Rel(i.context.Stager.DepDir(), i.agentPath)
	if err != nil {
		return fmt.Errorf("failed to determine relative path for Introscope agent: %w", err)
	}
	runtimeJarPath := filepath.Join("$DEPS_DIR/0", relPath)

	// Get credentials from service binding
	credentials := i.getCredentials()

	// Build all JAVA_OPTS options
	var opts []string
	opts = append(opts, fmt.Sprintf("-javaagent:%s", runtimeJarPath))

	// Configure agent name (default to application name)
	agentName := credentials.AgentName
	if agentName == "" {
		agentName = i.getApplicationName()
	}
	if agentName != "" {
		opts = append(opts, fmt.Sprintf("-Dcom.wily.introscope.agentProfile.agent.name=%s", agentName))
	}

	// Configure Enterprise Manager host
	if credentials.EMHost != "" {
		opts = append(opts, fmt.Sprintf("-Dcom.wily.introscope.agentProfile.agent.enterpriseManager.host=%s", credentials.EMHost))
	}

	// Configure Enterprise Manager port
	if credentials.EMPort != "" {
		opts = append(opts, fmt.Sprintf("-Dcom.wily.introscope.agentProfile.agent.enterpriseManager.port=%s", credentials.EMPort))
	}

	// Write all options to .opts file
	javaOpts := strings.Join(opts, " ")
	if err := writeJavaOptsFile(i.context, 27, "introscope_agent", javaOpts); err != nil {
		return fmt.Errorf("failed to write JAVA_OPTS for Introscope: %w", err)
	}

	i.context.Log.Info("Introscope agent configured")
	return nil
}

// hasServiceBinding checks if there's an introscope service binding
func (i *IntroscopeAgentFramework) hasServiceBinding() bool {
	// Use standard service detection helpers
	vcapServices, err := GetVCAPServices()
	if err != nil {
		i.context.Log.Warning("Failed to parse VCAP_SERVICES: %s", err.Error())
		return false
	}

	// Check for Introscope/CA APM service bindings using flexible patterns
	if vcapServices.HasService("introscope") ||
		vcapServices.HasService("ca-apm") ||
		vcapServices.HasService("ca-wily") ||
		vcapServices.HasService("wily-introscope") ||
		vcapServices.HasTag("introscope") ||
		vcapServices.HasTag("ca-apm") ||
		vcapServices.HasTag("wily") ||
		vcapServices.HasServiceByNamePattern("introscope") ||
		vcapServices.HasServiceByNamePattern("ca-apm") ||
		vcapServices.HasServiceByNamePattern("wily") {
		return true
	}

	return false
}

// IntroscopeCredentials holds Introscope agent credentials
type IntroscopeCredentials struct {
	AgentName string
	EMHost    string
	EMPort    string
}

// getCredentials retrieves Introscope credentials from service binding
func (i *IntroscopeAgentFramework) getCredentials() IntroscopeCredentials {
	creds := IntroscopeCredentials{}

	vcapServices, err := GetVCAPServices()
	if err != nil {
		return creds
	}

	// Find Introscope service using standard helpers
	var service *VCAPService

	// Try exact service labels first
	if svc := vcapServices.GetService("introscope"); svc != nil {
		service = svc
	} else if svc := vcapServices.GetService("ca-apm"); svc != nil {
		service = svc
	} else if svc := vcapServices.GetService("ca-wily"); svc != nil {
		service = svc
	} else if svc := vcapServices.GetService("wily-introscope"); svc != nil {
		service = svc
	} else {
		// Try user-provided services with introscope/ca-apm/wily in the name
		if svc := vcapServices.GetServiceByNamePattern("introscope"); svc != nil {
			service = svc
		} else if svc := vcapServices.GetServiceByNamePattern("ca-apm"); svc != nil {
			service = svc
		} else if svc := vcapServices.GetServiceByNamePattern("wily"); svc != nil {
			service = svc
		}
	}

	if service == nil {
		return creds
	}

	// Extract credentials with flexible key names
	if agentName, ok := service.Credentials["agent_name"].(string); ok {
		creds.AgentName = agentName
	} else if agentName, ok := service.Credentials["agentName"].(string); ok {
		creds.AgentName = agentName
	}

	if emHost, ok := service.Credentials["em_host"].(string); ok {
		creds.EMHost = emHost
	} else if emHost, ok := service.Credentials["emHost"].(string); ok {
		creds.EMHost = emHost
	}

	if emPort, ok := service.Credentials["em_port"].(string); ok {
		creds.EMPort = emPort
	} else if emPort, ok := service.Credentials["emPort"].(string); ok {
		creds.EMPort = emPort
	} else if emPort, ok := service.Credentials["em_port"].(float64); ok {
		creds.EMPort = fmt.Sprintf("%.0f", emPort)
	} else if emPort, ok := service.Credentials["emPort"].(float64); ok {
		creds.EMPort = fmt.Sprintf("%.0f", emPort)
	}

	return creds
}

// getApplicationName returns the application name from VCAP_APPLICATION
func (i *IntroscopeAgentFramework) getApplicationName() string {
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

