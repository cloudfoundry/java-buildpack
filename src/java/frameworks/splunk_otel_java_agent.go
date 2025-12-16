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

// SplunkOtelJavaAgentFramework represents the Splunk Distribution of OpenTelemetry Java agent framework
type SplunkOtelJavaAgentFramework struct {
	context *Context
	jarPath string
}

// NewSplunkOtelJavaAgentFramework creates a new Splunk OTEL Java agent framework instance
func NewSplunkOtelJavaAgentFramework(ctx *Context) *SplunkOtelJavaAgentFramework {
	return &SplunkOtelJavaAgentFramework{context: ctx}
}

// Detect checks if Splunk OTEL Java agent should be enabled
func (s *SplunkOtelJavaAgentFramework) Detect() (string, error) {
	// Check for SPLUNK_OTEL_AGENT environment variable
	if os.Getenv("SPLUNK_OTEL_AGENT") != "" {
		s.context.Log.Debug("Splunk OTEL Java agent framework detected via SPLUNK_OTEL_AGENT")
		return "Splunk OTEL", nil
	}

	// Check for OTEL_EXPORTER_OTLP_ENDPOINT
	if os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") != "" {
		s.context.Log.Debug("Splunk OTEL Java agent framework detected via OTEL_EXPORTER_OTLP_ENDPOINT")
		return "Splunk OTEL", nil
	}

	// Check for Splunk OTEL service binding
	vcapServices, err := GetVCAPServices()
	if err != nil {
		s.context.Log.Warning("Failed to parse VCAP_SERVICES: %s", err.Error())
		return "", nil
	}

	// Splunk OTEL can be bound as:
	// - "splunk" or "splunk-otel" service (marketplace or label)
	// - Services with "splunk" or "otel" tag
	// - User-provided services with these patterns in the name (Docker platform)
	if vcapServices.HasService("splunk") ||
		vcapServices.HasService("splunk-otel") ||
		vcapServices.HasTag("splunk") ||
		vcapServices.HasTag("otel") ||
		vcapServices.HasServiceByNamePattern("splunk") ||
		vcapServices.HasServiceByNamePattern("otel") {
		s.context.Log.Info("Splunk OTEL service detected!")
		return "Splunk OTEL", nil
	}

	s.context.Log.Debug("Splunk OTEL Java agent: no service binding or environment variables found")
	return "", nil
}

// Supply downloads and installs the Splunk OTEL Java agent
func (s *SplunkOtelJavaAgentFramework) Supply() error {
	s.context.Log.BeginStep("Installing Splunk OTEL Java agent")

	// Get dependency from manifest
	dep, err := s.context.Manifest.DefaultVersion("splunk-otel-java-agent")
	if err != nil {
		return fmt.Errorf("unable to find Splunk OTEL Java agent in manifest: %w", err)
	}

	// Install the agent
	agentDir := filepath.Join(s.context.Stager.DepDir(), "splunk_otel_java_agent")
	if err := s.context.Installer.InstallDependency(dep, agentDir); err != nil {
		return fmt.Errorf("failed to install Splunk OTEL Java agent: %w", err)
	}

	// Find the installed agent JAR
	jarPattern := filepath.Join(agentDir, "splunk-otel-javaagent.jar")
	if _, err := os.Stat(jarPattern); err != nil {
		// Try alternative name
		jarPattern = filepath.Join(agentDir, "splunk-otel-javaagent-all.jar")
		if _, err := os.Stat(jarPattern); err != nil {
			return fmt.Errorf("Splunk OTEL Java agent JAR not found after installation in %s (tried both splunk-otel-javaagent.jar and splunk-otel-javaagent-all.jar)", agentDir)
		}
	}
	s.jarPath = jarPattern

	s.context.Log.Info("Splunk OTEL Java agent %s installed", dep.Version)
	return nil
}

// Finalize configures the Splunk OTEL Java agent
func (s *SplunkOtelJavaAgentFramework) Finalize() error {
	if s.jarPath == "" {
		return nil
	}

	s.context.Log.BeginStep("Configuring Splunk OTEL Java agent")

	// Convert staging path to runtime path
	relPath, err := filepath.Rel(s.context.Stager.DepDir(), s.jarPath)
	if err != nil {
		return fmt.Errorf("failed to determine relative path for Splunk OTEL Java agent: %w", err)
	}
	runtimeJarPath := filepath.Join("$DEPS_DIR/0", relPath)

	// Get credentials from service binding
	credentials := s.getCredentials()

	// Build all JAVA_OPTS options
	var opts []string
	opts = append(opts, fmt.Sprintf("-javaagent:%s", runtimeJarPath))

	// Configure service name
	if appName := s.getApplicationName(); appName != "" {
		opts = append(opts, fmt.Sprintf("-Dotel.service.name=%s", appName))
	}

	// Configure OTLP endpoint
	if credentials.OTLPEndpoint != "" {
		opts = append(opts, fmt.Sprintf("-Dotel.exporter.otlp.endpoint=%s", credentials.OTLPEndpoint))
	}

	// Configure access token
	if credentials.AccessToken != "" {
		opts = append(opts, fmt.Sprintf("-Dsplunk.access.token=%s", credentials.AccessToken))
	}

	// Configure realm
	if credentials.Realm != "" {
		opts = append(opts, fmt.Sprintf("-Dsplunk.realm=%s", credentials.Realm))
	}

	// Write all options to .opts file
	javaOpts := strings.Join(opts, " ")
	if err := writeJavaOptsFile(s.context, 42, "splunk_otel_java_agent", javaOpts); err != nil {
		return fmt.Errorf("failed to write JAVA_OPTS for Splunk OTEL: %w", err)
	}

	s.context.Log.Info("Splunk OTEL Java agent configured")
	return nil
}

// SplunkCredentials holds Splunk OTEL credentials
type SplunkCredentials struct {
	OTLPEndpoint string
	AccessToken  string
	Realm        string
}

// getCredentials retrieves Splunk OTEL credentials
func (s *SplunkOtelJavaAgentFramework) getCredentials() SplunkCredentials {
	creds := SplunkCredentials{}

	// Check environment variables first
	creds.OTLPEndpoint = os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	creds.AccessToken = os.Getenv("SPLUNK_ACCESS_TOKEN")
	creds.Realm = os.Getenv("SPLUNK_REALM")

	if creds.OTLPEndpoint != "" {
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

	// Look for splunk service
	serviceNames := []string{
		"splunk",
		"splunk-otel",
		"user-provided",
	}

	for _, serviceName := range serviceNames {
		if serviceList, ok := services[serviceName]; ok {
			for _, service := range serviceList {
				if credentials, ok := service["credentials"].(map[string]interface{}); ok {
					// Get OTLP endpoint
					if endpoint, ok := credentials["otlp_endpoint"].(string); ok {
						creds.OTLPEndpoint = endpoint
					} else if endpoint, ok := credentials["otlpEndpoint"].(string); ok {
						creds.OTLPEndpoint = endpoint
					} else if endpoint, ok := credentials["endpoint"].(string); ok {
						creds.OTLPEndpoint = endpoint
					}

					// Get access token
					if token, ok := credentials["access_token"].(string); ok {
						creds.AccessToken = token
					} else if token, ok := credentials["accessToken"].(string); ok {
						creds.AccessToken = token
					} else if token, ok := credentials["token"].(string); ok {
						creds.AccessToken = token
					}

					// Get realm
					if realm, ok := credentials["realm"].(string); ok {
						creds.Realm = realm
					}

					if creds.OTLPEndpoint != "" {
						return creds
					}
				}
			}
		}
	}

	return creds
}

// getApplicationName returns the application name
func (s *SplunkOtelJavaAgentFramework) getApplicationName() string {
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

