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
)

// SkyWalkingAgentFramework represents the Apache SkyWalking agent framework
type SkyWalkingAgentFramework struct {
	context *Context
	jarPath string
}

// NewSkyWalkingAgentFramework creates a new SkyWalking agent framework instance
func NewSkyWalkingAgentFramework(ctx *Context) *SkyWalkingAgentFramework {
	return &SkyWalkingAgentFramework{context: ctx}
}

// Detect checks if SkyWalking agent should be enabled
func (s *SkyWalkingAgentFramework) Detect() (string, error) {
	// Check for SW_AGENT_COLLECTOR_BACKEND_SERVICES environment variable
	if os.Getenv("SW_AGENT_COLLECTOR_BACKEND_SERVICES") != "" {
		s.context.Log.Debug("SkyWalking agent framework detected via SW_AGENT_COLLECTOR_BACKEND_SERVICES")
		return "SkyWalking", nil
	}

	// Check for SkyWalking service binding
	vcapServices, err := GetVCAPServices()
	if err != nil {
		s.context.Log.Warning("Failed to parse VCAP_SERVICES: %s", err.Error())
		return "", nil
	}

	// SkyWalking can be bound as:
	// - "skywalking" service (marketplace or label)
	// - Services with "skywalking" tag
	// - User-provided services with "skywalking" in the name (Docker platform)
	if vcapServices.HasService("skywalking") ||
		vcapServices.HasTag("skywalking") ||
		vcapServices.HasServiceByNamePattern("skywalking") {
		s.context.Log.Info("SkyWalking service detected!")
		return "SkyWalking", nil
	}

	s.context.Log.Debug("SkyWalking agent: no service binding or environment variables found")
	return "", nil
}

// Supply downloads and installs the SkyWalking agent
func (s *SkyWalkingAgentFramework) Supply() error {
	s.context.Log.BeginStep("Installing SkyWalking agent")

	// Get dependency from manifest
	dep, err := s.context.Manifest.DefaultVersion("sky-walking-agent")
	if err != nil {
		return fmt.Errorf("unable to find SkyWalking agent in manifest: %w", err)
	}

	// Install the agent
	agentDir := filepath.Join(s.context.Stager.DepDir(), "sky_walking_agent")
	if err := s.context.Installer.InstallDependency(dep, agentDir); err != nil {
		return fmt.Errorf("failed to install SkyWalking agent: %w", err)
	}

	// Find the installed agent JAR
	jarPattern := filepath.Join(agentDir, "skywalking-agent.jar")
	if _, err := os.Stat(jarPattern); err != nil {
		return fmt.Errorf("SkyWalking agent JAR not found after installation: %w", err)
	}
	s.jarPath = jarPattern

	s.context.Log.Info("SkyWalking agent %s installed", dep.Version)
	return nil
}

// Finalize configures the SkyWalking agent
func (s *SkyWalkingAgentFramework) Finalize() error {
	if s.jarPath == "" {
		return nil
	}

	s.context.Log.BeginStep("Configuring SkyWalking agent")

	// Get credentials from service binding
	credentials := s.getCredentials()

	// Add javaagent to JAVA_OPTS
	javaagentOpt := fmt.Sprintf("-javaagent:%s", s.jarPath)
	if err := s.appendToJavaOpts(javaagentOpt); err != nil {
		s.context.Log.Warning("Failed to add SkyWalking agent to JAVA_OPTS: %s", err)
		return nil
	}

	// Configure application name (default to space:application_name)
	appName := s.getApplicationName()
	if appName != "" {
		nameOpt := fmt.Sprintf("-Dskywalking.agent.service_name=%s", appName)
		if err := s.appendToJavaOpts(nameOpt); err != nil {
			s.context.Log.Warning("Failed to set service name: %s", err)
		}
	}

	// Configure collector backend services
	if credentials.CollectorBackendServices != "" {
		backendOpt := fmt.Sprintf("-Dskywalking.collector.backend_service=%s", credentials.CollectorBackendServices)
		if err := s.appendToJavaOpts(backendOpt); err != nil {
			s.context.Log.Warning("Failed to set collector backend services: %s", err)
		}
	}

	s.context.Log.Info("SkyWalking agent configured")
	return nil
}

// hasServiceBinding checks if there's a skywalking service binding

// SkyWalkingCredentials holds SkyWalking agent credentials
type SkyWalkingCredentials struct {
	CollectorBackendServices string
}

// getCredentials retrieves SkyWalking credentials
func (s *SkyWalkingAgentFramework) getCredentials() SkyWalkingCredentials {
	creds := SkyWalkingCredentials{}

	// Check environment variable first
	creds.CollectorBackendServices = os.Getenv("SW_AGENT_COLLECTOR_BACKEND_SERVICES")
	if creds.CollectorBackendServices != "" {
		return creds
	}

	// Check service binding
	vcapServices := os.Getenv("VCAP_SERVICES")
	if vcapServices == "" {
		return creds
	}

	var services map[string][]map[string]interface{}
	if err := json.Unmarshal([]byte(vcapServices), &services); err != nil {
		return creds
	}

	// Look for skywalking service
	serviceNames := []string{
		"skywalking",
		"sky-walking",
		"user-provided",
	}

	for _, serviceName := range serviceNames {
		if serviceList, ok := services[serviceName]; ok {
			for _, service := range serviceList {
				if credentials, ok := service["credentials"].(map[string]interface{}); ok {
					// Get collector backend services
					if backend, ok := credentials["collector_backend_services"].(string); ok {
						creds.CollectorBackendServices = backend
						return creds
					}
					if backend, ok := credentials["collectorBackendServices"].(string); ok {
						creds.CollectorBackendServices = backend
						return creds
					}
					if backend, ok := credentials["backend_service"].(string); ok {
						creds.CollectorBackendServices = backend
						return creds
					}
				}
			}
		}
	}

	return creds
}

// getApplicationName returns the application name in format "space:application_name"
func (s *SkyWalkingAgentFramework) getApplicationName() string {
	vcapApp := os.Getenv("VCAP_APPLICATION")
	if vcapApp == "" {
		return ""
	}

	var appData map[string]interface{}
	if err := json.Unmarshal([]byte(vcapApp), &appData); err != nil {
		return ""
	}

	spaceName, hasSpace := appData["space_name"].(string)
	appName, hasApp := appData["application_name"].(string)

	if hasSpace && hasApp {
		return fmt.Sprintf("%s:%s", spaceName, appName)
	}

	if hasApp {
		return appName
	}

	return ""
}

// appendToJavaOpts appends a value to JAVA_OPTS
func (s *SkyWalkingAgentFramework) appendToJavaOpts(value string) error {
	javaOptsFile := filepath.Join(s.context.Stager.DepDir(), "env", "JAVA_OPTS")

	// Read existing JAVA_OPTS
	var existingOpts string
	if data, err := os.ReadFile(javaOptsFile); err == nil {
		existingOpts = string(data)
	}

	// Append new value
	if existingOpts != "" {
		existingOpts += " "
	}
	existingOpts += value

	// Write back
	return s.context.Stager.WriteEnvFile(javaOptsFile, existingOpts)
}
