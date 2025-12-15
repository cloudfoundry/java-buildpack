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

// GoogleStackdriverProfilerFramework represents the Google Stackdriver Profiler framework
type GoogleStackdriverProfilerFramework struct {
	context   *Context
	agentPath string
}

// NewGoogleStackdriverProfilerFramework creates a new Google Stackdriver Profiler framework instance
func NewGoogleStackdriverProfilerFramework(ctx *Context) *GoogleStackdriverProfilerFramework {
	return &GoogleStackdriverProfilerFramework{context: ctx}
}

// Detect checks if Google Stackdriver Profiler should be enabled
func (g *GoogleStackdriverProfilerFramework) Detect() (string, error) {
	// Check for GOOGLE_APPLICATION_CREDENTIALS
	if os.Getenv("GOOGLE_APPLICATION_CREDENTIALS") != "" {
		g.context.Log.Debug("Google Stackdriver Profiler framework detected via GOOGLE_APPLICATION_CREDENTIALS")
		return "google-stackdriver-profiler", nil
	}

	// Check for google-stackdriver-profiler service binding
	vcapServices, err := GetVCAPServices()
	if err != nil {
		g.context.Log.Warning("Failed to parse VCAP_SERVICES: %s", err.Error())
		return "", nil
	}

	// Google Stackdriver Profiler can be bound as:
	// - "google-stackdriver-profiler" or "stackdriver-profiler" service (marketplace or label)
	// - Services with "stackdriver-profiler" tag
	// - User-provided services with these patterns in the name (Docker platform)
	if vcapServices.HasService("google-stackdriver-profiler") ||
		vcapServices.HasService("stackdriver-profiler") ||
		vcapServices.HasTag("stackdriver-profiler") ||
		vcapServices.HasServiceByNamePattern("stackdriver-profiler") ||
		vcapServices.HasServiceByNamePattern("stackdriver") {
		g.context.Log.Info("Google Stackdriver Profiler service detected!")
		return "google-stackdriver-profiler", nil
	}

	g.context.Log.Debug("Google Stackdriver Profiler: no service binding or environment variables found")
	return "", nil
}

// Supply downloads and installs the Google Stackdriver Profiler
func (g *GoogleStackdriverProfilerFramework) Supply() error {
	g.context.Log.BeginStep("Installing Google Stackdriver Profiler")

	// Get dependency from manifest
	dep, err := g.context.Manifest.DefaultVersion("google-stackdriver-profiler")
	if err != nil {
		return fmt.Errorf("unable to find Google Stackdriver Profiler in manifest: %w", err)
	}

	// Install the profiler
	profilerDir := filepath.Join(g.context.Stager.DepDir(), "google_stackdriver_profiler")
	if err := g.context.Installer.InstallDependency(dep, profilerDir); err != nil {
		return fmt.Errorf("failed to install Google Stackdriver Profiler: %w", err)
	}

	// Find the installed agent (native library)
	agentPattern := filepath.Join(profilerDir, "profiler_java_agent.so")
	if _, err := os.Stat(agentPattern); err != nil {
		return fmt.Errorf("Google Stackdriver Profiler agent not found after installation: %w", err)
	}
	g.agentPath = agentPattern

	g.context.Log.Info("Google Stackdriver Profiler %s installed", dep.Version)
	return nil
}

// Finalize configures the Google Stackdriver Profiler
func (g *GoogleStackdriverProfilerFramework) Finalize() error {
	if g.agentPath == "" {
		return nil
	}

	g.context.Log.BeginStep("Configuring Google Stackdriver Profiler")

	// Get credentials
	credentials := g.getCredentials()

	// Add agentpath to JAVA_OPTS
	agentOpt := fmt.Sprintf("-agentpath:%s", g.agentPath)

	// Add service name (application name)
	if appName := g.getApplicationName(); appName != "" {
		agentOpt += fmt.Sprintf("=-cprof_service=%s", appName)
	}

	// Add service version
	if appVersion := g.getApplicationVersion(); appVersion != "" {
		agentOpt += fmt.Sprintf(",-cprof_service_version=%s", appVersion)
	}

	// Add project ID if available
	if credentials.ProjectID != "" {
		agentOpt += fmt.Sprintf(",-cprof_project_id=%s", credentials.ProjectID)
	}

	if err := g.appendToJavaOpts(agentOpt); err != nil {
		g.context.Log.Warning("Failed to add Google Stackdriver Profiler to JAVA_OPTS: %s", err)
		return nil
	}

	g.context.Log.Info("Google Stackdriver Profiler configured")
	return nil
}

// GoogleProfilerCredentials holds Google Cloud credentials
type GoogleProfilerCredentials struct {
	ProjectID string
}

// getCredentials retrieves Google Cloud credentials
func (g *GoogleStackdriverProfilerFramework) getCredentials() GoogleProfilerCredentials {
	creds := GoogleProfilerCredentials{}

	vcapServices := os.Getenv("VCAP_SERVICES")
	if vcapServices == "" {
		return creds
	}

	var services map[string][]map[string]interface{}
	if err := json.Unmarshal([]byte(vcapServices), &services); err != nil {
		return creds
	}

	// Look for Google service
	serviceNames := []string{
		"google-stackdriver-profiler",
		"stackdriver-profiler",
		"user-provided",
	}

	for _, serviceName := range serviceNames {
		if serviceList, ok := services[serviceName]; ok {
			for _, service := range serviceList {
				if credentials, ok := service["credentials"].(map[string]interface{}); ok {
					if projectID, ok := credentials["ProjectId"].(string); ok {
						creds.ProjectID = projectID
						return creds
					}
					if projectID, ok := credentials["project_id"].(string); ok {
						creds.ProjectID = projectID
						return creds
					}
				}
			}
		}
	}

	return creds
}

// getApplicationName returns the application name
func (g *GoogleStackdriverProfilerFramework) getApplicationName() string {
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

// getApplicationVersion returns the application version
func (g *GoogleStackdriverProfilerFramework) getApplicationVersion() string {
	vcapApp := os.Getenv("VCAP_APPLICATION")
	if vcapApp == "" {
		return ""
	}

	var appData map[string]interface{}
	if err := json.Unmarshal([]byte(vcapApp), &appData); err != nil {
		return ""
	}

	if version, ok := appData["application_version"].(string); ok {
		return version
	}

	return ""
}

// appendToJavaOpts appends a value to JAVA_OPTS
func (g *GoogleStackdriverProfilerFramework) appendToJavaOpts(value string) error {
	javaOptsFile := filepath.Join(g.context.Stager.DepDir(), "env", "JAVA_OPTS")

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
	return g.context.Stager.WriteEnvFile(javaOptsFile, existingOpts)
}
