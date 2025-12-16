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
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// CheckmarxIASTAgentFramework represents the Checkmarx IAST agent framework
type CheckmarxIASTAgentFramework struct {
	context *Context
	jarPath string
}

// NewCheckmarxIASTAgentFramework creates a new Checkmarx IAST agent framework instance
func NewCheckmarxIASTAgentFramework(ctx *Context) *CheckmarxIASTAgentFramework {
	return &CheckmarxIASTAgentFramework{context: ctx}
}

// Detect checks if Checkmarx IAST agent should be enabled
func (c *CheckmarxIASTAgentFramework) Detect() (string, error) {
	// Use standard service detection helpers
	vcapServices, err := GetVCAPServices()
	if err != nil {
		c.context.Log.Warning("Failed to parse VCAP_SERVICES: %s", err.Error())
		return "", nil
	}

	// Check for Checkmarx service bindings using flexible patterns
	if vcapServices.HasService("checkmarx-iast") ||
		vcapServices.HasService("checkmarx") ||
		vcapServices.HasTag("checkmarx-iast") ||
		vcapServices.HasTag("checkmarx") ||
		vcapServices.HasTag("iast") ||
		vcapServices.HasServiceByNamePattern("checkmarx") {
		c.context.Log.Debug("Checkmarx IAST agent framework detected via service binding")
		return "checkmarx-iast-agent", nil
	}

	c.context.Log.Debug("Checkmarx IAST agent: no service binding found")
	return "", nil
}

// Supply downloads and installs the Checkmarx IAST agent
func (c *CheckmarxIASTAgentFramework) Supply() error {
	c.context.Log.BeginStep("Installing Checkmarx IAST agent")

	// Get credentials from service binding
	credentials := c.getCredentials()
	if credentials.URL == "" {
		return fmt.Errorf("Checkmarx IAST agent URL not found in service binding credentials")
	}

	// Download the agent from the URL provided in service credentials
	agentDir := filepath.Join(c.context.Stager.DepDir(), "checkmarx_iast_agent")
	if err := os.MkdirAll(agentDir, 0755); err != nil {
		return fmt.Errorf("failed to create Checkmarx IAST agent directory: %w", err)
	}

	jarPath := filepath.Join(agentDir, "cx-agent.jar")
	if err := c.downloadAgent(credentials.URL, jarPath); err != nil {
		return fmt.Errorf("failed to download Checkmarx IAST agent: %w", err)
	}

	c.jarPath = jarPath
	c.context.Log.Info("Checkmarx IAST agent installed from %s", credentials.URL)
	return nil
}

// Finalize configures the Checkmarx IAST agent
func (c *CheckmarxIASTAgentFramework) Finalize() error {
	if c.jarPath == "" {
		return nil
	}

	c.context.Log.BeginStep("Configuring Checkmarx IAST agent")

	// Convert staging path to runtime path
	relPath, err := filepath.Rel(c.context.Stager.DepDir(), c.jarPath)
	if err != nil {
		return fmt.Errorf("failed to determine relative path for Checkmarx IAST agent: %w", err)
	}
	runtimeJarPath := filepath.Join("$DEPS_DIR/0", relPath)

	// Build all JAVA_OPTS options
	var opts []string
	opts = append(opts, fmt.Sprintf("-javaagent:%s", runtimeJarPath))

	// Get credentials
	credentials := c.getCredentials()

	// Set Checkmarx manager URL if available
	if credentials.ManagerURL != "" {
		opts = append(opts, fmt.Sprintf("-Dcheckmarx.manager.url=%s", credentials.ManagerURL))
	}

	// Set API key if available
	if credentials.APIKey != "" {
		opts = append(opts, fmt.Sprintf("-Dcheckmarx.api.key=%s", credentials.APIKey))
	}

	// Write all options to .opts file
	javaOpts := strings.Join(opts, " ")
	if err := writeJavaOptsFile(c.context, 14, "checkmarx_iast_agent", javaOpts); err != nil {
		return fmt.Errorf("failed to write JAVA_OPTS for Checkmarx IAST: %w", err)
	}

	c.context.Log.Info("Checkmarx IAST agent configured")
	return nil
}

// CheckmarxCredentials holds Checkmarx IAST credentials
type CheckmarxCredentials struct {
	URL        string // Agent download URL
	ManagerURL string // Checkmarx manager URL
	APIKey     string // API key for authentication
}

// getCredentials retrieves Checkmarx IAST credentials from service binding
func (c *CheckmarxIASTAgentFramework) getCredentials() CheckmarxCredentials {
	creds := CheckmarxCredentials{}

	vcapServices, err := GetVCAPServices()
	if err != nil {
		return creds
	}

	// Find Checkmarx service using standard helpers
	var service *VCAPService

	// Try exact service labels first
	if svc := vcapServices.GetService("checkmarx-iast"); svc != nil {
		service = svc
	} else if svc := vcapServices.GetService("checkmarx"); svc != nil {
		service = svc
	} else {
		// Try user-provided services with checkmarx in the name
		service = vcapServices.GetServiceByNamePattern("checkmarx")
	}

	if service == nil {
		return creds
	}

	// Extract credentials with flexible key names
	if url, ok := service.Credentials["url"].(string); ok {
		creds.URL = url
	} else if url, ok := service.Credentials["agent_url"].(string); ok {
		creds.URL = url
	}

	if managerURL, ok := service.Credentials["manager_url"].(string); ok {
		creds.ManagerURL = managerURL
	} else if managerURL, ok := service.Credentials["managerUrl"].(string); ok {
		creds.ManagerURL = managerURL
	}

	if apiKey, ok := service.Credentials["api_key"].(string); ok {
		creds.APIKey = apiKey
	} else if apiKey, ok := service.Credentials["apiKey"].(string); ok {
		creds.APIKey = apiKey
	}

	return creds
}

// downloadAgent downloads the agent JAR from the given URL
func (c *CheckmarxIASTAgentFramework) downloadAgent(url, destPath string) error {
	c.context.Log.Debug("Downloading Checkmarx IAST agent from %s", url)

	resp, err := http.Get(url)
	if err != nil {
		return fmt.Errorf("failed to download agent: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to download agent: HTTP %d", resp.StatusCode)
	}

	outFile, err := os.Create(destPath)
	if err != nil {
		return fmt.Errorf("failed to create destination file: %w", err)
	}
	defer outFile.Close()

	if _, err := io.Copy(outFile, resp.Body); err != nil {
		return fmt.Errorf("failed to write agent file: %w", err)
	}

	return nil
}
