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

// GoogleStackdriverDebuggerFramework represents the Google Stackdriver Debugger framework
type GoogleStackdriverDebuggerFramework struct {
	context   *Context
	agentPath string
}

// NewGoogleStackdriverDebuggerFramework creates a new Google Stackdriver Debugger framework instance
func NewGoogleStackdriverDebuggerFramework(ctx *Context) *GoogleStackdriverDebuggerFramework {
	return &GoogleStackdriverDebuggerFramework{context: ctx}
}

// Detect checks if Google Stackdriver Debugger should be enabled
func (g *GoogleStackdriverDebuggerFramework) Detect() (string, error) {
	// Check for google-stackdriver-debugger service binding
	if g.hasServiceBinding() {
		g.context.Log.Debug("Google Stackdriver Debugger framework detected via service binding")
		return "google-stackdriver-debugger", nil
	}

	// Check for GOOGLE_APPLICATION_CREDENTIALS
	if os.Getenv("GOOGLE_APPLICATION_CREDENTIALS") != "" {
		g.context.Log.Debug("Google Stackdriver Debugger framework detected via GOOGLE_APPLICATION_CREDENTIALS")
		return "google-stackdriver-debugger", nil
	}

	g.context.Log.Debug("Google Stackdriver Debugger: no service binding found")
	return "", nil
}

// Supply downloads and installs the Google Stackdriver Debugger
func (g *GoogleStackdriverDebuggerFramework) Supply() error {
	g.context.Log.BeginStep("Installing Google Stackdriver Debugger")

	// Get dependency from manifest
	dep, err := g.context.Manifest.DefaultVersion("google-stackdriver-debugger")
	if err != nil {
		return fmt.Errorf("unable to find Google Stackdriver Debugger in manifest: %w", err)
	}

	// Install the debugger
	debuggerDir := filepath.Join(g.context.Stager.DepDir(), "google_stackdriver_debugger")
	if err := g.context.Installer.InstallDependency(dep, debuggerDir); err != nil {
		return fmt.Errorf("failed to install Google Stackdriver Debugger: %w", err)
	}

	// Find the installed agent (native library)
	agentPattern := filepath.Join(debuggerDir, "cdbg_java_agent.so")
	if _, err := os.Stat(agentPattern); err != nil {
		return fmt.Errorf("Google Stackdriver Debugger agent not found after installation: %w", err)
	}
	g.agentPath = agentPattern

	g.context.Log.Info("Google Stackdriver Debugger %s installed", dep.Version)
	return nil
}

// Finalize configures the Google Stackdriver Debugger
func (g *GoogleStackdriverDebuggerFramework) Finalize() error {
	if g.agentPath == "" {
		return nil
	}

	g.context.Log.BeginStep("Configuring Google Stackdriver Debugger")

	// Convert staging path to runtime path
	relPath, err := filepath.Rel(g.context.Stager.DepDir(), g.agentPath)
	if err != nil {
		return fmt.Errorf("failed to determine relative path for Google Stackdriver Debugger: %w", err)
	}
	runtimeAgentPath := filepath.Join("$DEPS_DIR/0", relPath)

	// Get credentials
	credentials := g.getCredentials()

	// Build all JAVA_OPTS options
	var opts []string

	// Add agentpath with project ID if available
	if credentials.ProjectID != "" {
		opts = append(opts, fmt.Sprintf("-agentpath:%s=-Dcom.google.cdbg.module=%s", runtimeAgentPath, credentials.ProjectID))
	} else {
		opts = append(opts, fmt.Sprintf("-agentpath:%s", runtimeAgentPath))
	}

	// Set application version
	if appVersion := g.getApplicationVersion(); appVersion != "" {
		opts = append(opts, fmt.Sprintf("-Dcom.google.cdbg.version=%s", appVersion))
	}

	// Write all options to .opts file
	javaOpts := strings.Join(opts, " ")
	if err := writeJavaOptsFile(g.context, 21, "google_stackdriver_debugger", javaOpts); err != nil {
		return fmt.Errorf("failed to write JAVA_OPTS for Google Stackdriver Debugger: %w", err)
	}

	g.context.Log.Info("Google Stackdriver Debugger configured")
	return nil
}

// hasServiceBinding checks if there's a google-stackdriver-debugger service binding
func (g *GoogleStackdriverDebuggerFramework) hasServiceBinding() bool {
	vcapServices, err := GetVCAPServices()
	if err != nil {
		g.context.Log.Debug("Failed to parse VCAP_SERVICES: %s", err.Error())
		return false
	}

	// Check for Google Stackdriver Debugger service binding via multiple methods
	if vcapServices.HasService("google-stackdriver-debugger") ||
		vcapServices.HasService("stackdriver-debugger") ||
		vcapServices.HasTag("stackdriver-debugger") ||
		vcapServices.HasTag("stackdriver") ||
		vcapServices.HasServiceByNamePattern("stackdriver-debugger") ||
		vcapServices.HasServiceByNamePattern("stackdriver") {
		return true
	}

	return false
}

// GoogleCredentials holds Google Cloud credentials
type GoogleCredentials struct {
	ProjectID string
}

// getCredentials retrieves Google Cloud credentials
func (g *GoogleStackdriverDebuggerFramework) getCredentials() GoogleCredentials {
	creds := GoogleCredentials{}

	vcapServices, err := GetVCAPServices()
	if err != nil {
		return creds
	}

	// Try to find service by exact label first
	var service *VCAPService
	if svc := vcapServices.GetService("google-stackdriver-debugger"); svc != nil {
		service = svc
	} else if svc := vcapServices.GetService("stackdriver-debugger"); svc != nil {
		service = svc
	} else {
		// Fall back to pattern matching for user-provided services
		service = vcapServices.GetServiceByNamePattern("stackdriver-debugger")
		if service == nil {
			service = vcapServices.GetServiceByNamePattern("stackdriver")
		}
	}

	if service == nil {
		return creds
	}

	// Extract project ID - try multiple key variations
	if projectID, ok := service.Credentials["ProjectId"].(string); ok {
		creds.ProjectID = projectID
	} else if projectID, ok := service.Credentials["project_id"].(string); ok {
		creds.ProjectID = projectID
	}

	return creds
}

// getApplicationVersion returns the application version
func (g *GoogleStackdriverDebuggerFramework) getApplicationVersion() string {
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
