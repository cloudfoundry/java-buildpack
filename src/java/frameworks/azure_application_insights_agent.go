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

// AzureApplicationInsightsAgentFramework represents the Azure Application Insights Java agent framework
type AzureApplicationInsightsAgentFramework struct {
	context *Context
	jarPath string
}

// NewAzureApplicationInsightsAgentFramework creates a new Azure Application Insights agent framework instance
func NewAzureApplicationInsightsAgentFramework(ctx *Context) *AzureApplicationInsightsAgentFramework {
	return &AzureApplicationInsightsAgentFramework{context: ctx}
}

// Detect checks if Azure Application Insights should be enabled
func (a *AzureApplicationInsightsAgentFramework) Detect() (string, error) {
	// Check for connection string environment variable
	if os.Getenv("APPLICATIONINSIGHTS_CONNECTION_STRING") != "" {
		a.context.Log.Debug("Azure Application Insights agent framework detected via APPLICATIONINSIGHTS_CONNECTION_STRING")
		return "Azure Application Insights", nil
	}

	// Check for instrumentation key environment variable
	if os.Getenv("APPINSIGHTS_INSTRUMENTATIONKEY") != "" {
		a.context.Log.Debug("Azure Application Insights agent framework detected via APPINSIGHTS_INSTRUMENTATIONKEY")
		return "Azure Application Insights", nil
	}

	// Check for Azure Application Insights service binding
	vcapServices, err := GetVCAPServices()
	if err != nil {
		a.context.Log.Warning("Failed to parse VCAP_SERVICES: %s", err.Error())
		return "", nil
	}

	// Azure Application Insights can be bound as:
	// - "azure-application-insights" service (marketplace or label)
	// - "application-insights" or "applicationinsights" service
	// - Services with "application-insights", "applicationinsights", or "app-insights" tag
	// - User-provided services with these patterns in the name (Docker platform)
	if vcapServices.HasService("azure-application-insights") ||
		vcapServices.HasService("application-insights") ||
		vcapServices.HasService("applicationinsights") ||
		vcapServices.HasTag("application-insights") ||
		vcapServices.HasTag("applicationinsights") ||
		vcapServices.HasTag("app-insights") ||
		vcapServices.HasServiceByNamePattern("application-insights") ||
		vcapServices.HasServiceByNamePattern("applicationinsights") ||
		vcapServices.HasServiceByNamePattern("app-insights") ||
		vcapServices.HasServiceByNamePattern("insights") {
		a.context.Log.Info("Azure Application Insights service detected!")
		return "Azure Application Insights", nil
	}

	a.context.Log.Debug("Azure Application Insights agent: no service binding or environment variables found")
	return "", nil
}

// Supply downloads and installs the Azure Application Insights agent
func (a *AzureApplicationInsightsAgentFramework) Supply() error {
	a.context.Log.BeginStep("Installing Azure Application Insights agent")

	// Get dependency from manifest
	dep, err := a.context.Manifest.DefaultVersion("azure-application-insights-agent")
	if err != nil {
		return fmt.Errorf("unable to find Azure Application Insights agent in manifest: %w", err)
	}

	// Install the agent
	agentDir := filepath.Join(a.context.Stager.DepDir(), "azure_application_insights_agent")
	if err := a.context.Installer.InstallDependency(dep, agentDir); err != nil {
		return fmt.Errorf("failed to install Azure Application Insights agent: %w", err)
	}

	// Find the installed JAR
	jarPattern := filepath.Join(agentDir, "applicationinsights-agent-*.jar")
	matches, err := filepath.Glob(jarPattern)
	if err != nil {
		return fmt.Errorf("failed to search for Azure Application Insights agent JAR: %w", err)
	}
	if len(matches) == 0 {
		return fmt.Errorf("Azure Application Insights agent JAR not found after installation in %s", agentDir)
	}
	a.jarPath = matches[0]

	a.context.Log.Info("Azure Application Insights agent %s installed", dep.Version)
	return nil
}

// Finalize configures the Azure Application Insights agent
func (a *AzureApplicationInsightsAgentFramework) Finalize() error {
	if a.jarPath == "" {
		return nil
	}

	a.context.Log.BeginStep("Configuring Azure Application Insights agent")

	// Add javaagent to JAVA_OPTS
	javaagentOpt := fmt.Sprintf("-javaagent:%s", a.jarPath)
	if err := a.appendToJavaOpts(javaagentOpt); err != nil {
		a.context.Log.Warning("Failed to add Azure Application Insights agent to JAVA_OPTS: %s", err)
		return nil
	}

	// Get credentials from service binding or environment
	credentials := a.getCredentials()

	// Set connection string if available
	if credentials.ConnectionString != "" {
		connOpt := fmt.Sprintf("-Dapplicationinsights.connection.string=%s", credentials.ConnectionString)
		if err := a.appendToJavaOpts(connOpt); err != nil {
			a.context.Log.Warning("Failed to set connection string: %s", err)
		}
	} else if credentials.InstrumentationKey != "" {
		// Fallback to instrumentation key
		keyOpt := fmt.Sprintf("-Dapplicationinsights.instrumentation-key=%s", credentials.InstrumentationKey)
		if err := a.appendToJavaOpts(keyOpt); err != nil {
			a.context.Log.Warning("Failed to set instrumentation key: %s", err)
		}
	}

	// Set cloud role name (application name)
	if appName := a.getApplicationName(); appName != "" {
		roleOpt := fmt.Sprintf("-Dapplicationinsights.role.name=%s", appName)
		if err := a.appendToJavaOpts(roleOpt); err != nil {
			a.context.Log.Warning("Failed to set cloud role name: %s", err)
		}
	}

	a.context.Log.Info("Azure Application Insights agent configured")
	return nil
}

// AzureCredentials holds Azure Application Insights credentials
type AzureCredentials struct {
	ConnectionString   string
	InstrumentationKey string
}

// getCredentials retrieves Azure Application Insights credentials
func (a *AzureApplicationInsightsAgentFramework) getCredentials() AzureCredentials {
	creds := AzureCredentials{}

	// Check environment variables first
	creds.ConnectionString = os.Getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
	creds.InstrumentationKey = os.Getenv("APPINSIGHTS_INSTRUMENTATIONKEY")

	if creds.ConnectionString != "" || creds.InstrumentationKey != "" {
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

	// Look for Azure Application Insights service
	serviceNames := []string{
		"azure-application-insights",
		"application-insights",
		"applicationinsights",
		"user-provided",
	}

	for _, serviceName := range serviceNames {
		if serviceList, ok := services[serviceName]; ok {
			for _, service := range serviceList {
				if credentials, ok := service["credentials"].(map[string]interface{}); ok {
					// Try connection_string
					if connStr, ok := credentials["connection_string"].(string); ok {
						creds.ConnectionString = connStr
						return creds
					}
					if connStr, ok := credentials["connectionString"].(string); ok {
						creds.ConnectionString = connStr
						return creds
					}

					// Try instrumentation_key
					if key, ok := credentials["instrumentation_key"].(string); ok {
						creds.InstrumentationKey = key
						return creds
					}
					if key, ok := credentials["instrumentationKey"].(string); ok {
						creds.InstrumentationKey = key
						return creds
					}
				}
			}
		}
	}

	return creds
}

// appendToJavaOpts appends a value to JAVA_OPTS
func (a *AzureApplicationInsightsAgentFramework) appendToJavaOpts(value string) error {
	javaOptsFile := filepath.Join(a.context.Stager.DepDir(), "env", "JAVA_OPTS")

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
	return a.context.Stager.WriteEnvFile(javaOptsFile, existingOpts)
}

// getApplicationName returns the application name from VCAP_APPLICATION
func (a *AzureApplicationInsightsAgentFramework) getApplicationName() string {
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
