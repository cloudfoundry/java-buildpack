// Cloud Foundry Java Buildpack
// Copyright 2013-2020 the original author or authors.
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
	"regexp"
	"strings"
)

// ElasticApmAgentFramework represents the Elastic APM Java agent framework
type ElasticApmAgentFramework struct {
	context *Context
	jarPath string
	service *VCAPService
}

// NewElasticApmAgentFramework creates a new Elastic APM agent framework instance
func NewElasticApmAgentFramework(ctx *Context) *ElasticApmAgentFramework {
	return &ElasticApmAgentFramework{context: ctx}
}

// Detect checks if Elastic APM service is bound
func (e *ElasticApmAgentFramework) Detect() (string, error) {
	// Look for elastic-apm service with required credentials
	service := e.findElasticApmService()
	if service == nil {
		e.context.Log.Debug("Elastic APM Agent: No elastic-apm service found")
		return "", nil
	}

	// Check for required credentials: server_urls and secret_token
	if !e.hasRequiredCredentials(service) {
		e.context.Log.Debug("Elastic APM Agent: Service missing required credentials (server_urls, secret_token)")
		return "", nil
	}

	e.service = service
	e.context.Log.Debug("Elastic APM Agent framework detected")
	return "elastic-apm-agent", nil
}

// Supply downloads and installs the Elastic APM agent
func (e *ElasticApmAgentFramework) Supply() error {
	e.context.Log.BeginStep("Installing Elastic APM agent")

	// Get dependency from manifest
	dep, err := e.context.Manifest.DefaultVersion("elastic-apm-agent")
	if err != nil {
		return fmt.Errorf("unable to find Elastic APM agent in manifest: %w", err)
	}

	// Install the agent
	elasticDir := filepath.Join(e.context.Stager.DepDir(), "elastic_apm_agent")
	if err := e.context.Installer.InstallDependency(dep, elasticDir); err != nil {
		return fmt.Errorf("failed to install Elastic APM agent: %w", err)
	}

	// Find the installed JAR
	jarPattern := filepath.Join(elasticDir, "elastic-apm-agent*.jar")
	matches, err := filepath.Glob(jarPattern)
	if err != nil {
		return fmt.Errorf("failed to search for Elastic APM agent JAR: %w", err)
	}
	if len(matches) == 0 {
		return fmt.Errorf("Elastic APM agent JAR not found after installation in %s", elasticDir)
	}
	e.jarPath = matches[0]

	e.context.Log.Info("Elastic APM agent %s installed", dep.Version)
	return nil
}

// Finalize configures the Elastic APM agent
func (e *ElasticApmAgentFramework) Finalize() error {
	if e.jarPath == "" || e.service == nil {
		return nil
	}

	e.context.Log.BeginStep("Configuring Elastic APM agent")

	// Convert staging paths to runtime paths
	relJarPath, err := filepath.Rel(e.context.Stager.DepDir(), e.jarPath)
	if err != nil {
		return fmt.Errorf("failed to determine relative path for Elastic APM agent: %w", err)
	}
	runtimeJarPath := filepath.Join("$DEPS_DIR/0", relJarPath)
	runtimeHomeDir := "$DEPS_DIR/0/elastic_apm_agent"

	// Build configuration map
	config := e.buildConfiguration()

	// Build all JAVA_OPTS options
	var opts []string

	// Add configuration as system properties
	for key, value := range config {
		sysProp := e.formatSystemProperty(key, value)
		opts = append(opts, sysProp)
	}

	// Add javaagent
	opts = append(opts, fmt.Sprintf("-javaagent:%s", runtimeJarPath))

	// Add elastic.apm.home system property
	opts = append(opts, fmt.Sprintf("-Delastic.apm.home=%s", runtimeHomeDir))

	// Write all options to .opts file
	javaOpts := strings.Join(opts, " ")
	if err := writeJavaOptsFile(e.context, 19, "elastic_apm_agent", javaOpts); err != nil {
		return fmt.Errorf("failed to write JAVA_OPTS for Elastic APM: %w", err)
	}

	e.context.Log.Info("Elastic APM agent configured")
	return nil
}

// findElasticApmService finds the elastic-apm service binding
func (e *ElasticApmAgentFramework) findElasticApmService() *VCAPService {
	vcapServices, err := GetVCAPServices()
	if err != nil {
		return nil
	}

	// Use helper methods for detection
	// Elastic APM can be bound as:
	// - "elastic-apm" service (marketplace or label)
	// - Services with "elastic-apm" or "elastic" tag
	// - User-provided services with these patterns in the name (Docker platform)
	if vcapServices.HasService("elastic-apm") ||
		vcapServices.HasService("elastic") ||
		vcapServices.HasTag("elastic-apm") ||
		vcapServices.HasTag("elastic") {
		// Return first elastic-apm service from any label
		for _, services := range vcapServices {
			if len(services) > 0 {
				// Check if this service has elastic-apm tags or credentials
				for _, service := range services {
					for _, tag := range service.Tags {
						if strings.Contains(strings.ToLower(tag), "elastic") {
							return &service
						}
					}
				}
			}
		}
	}

	// Check user-provided services by name pattern
	if vcapServices.HasServiceByNamePattern("elastic-apm") ||
		vcapServices.HasServiceByNamePattern("elastic") {
		// Look for service with elastic in the name
		if userProvided, ok := vcapServices["user-provided"]; ok {
			for _, service := range userProvided {
				if strings.Contains(strings.ToLower(service.Name), "elastic") {
					return &service
				}
			}
		}
	}

	return nil
}

// hasRequiredCredentials checks if service has server_url(s) and secret_token
func (e *ElasticApmAgentFramework) hasRequiredCredentials(service *VCAPService) bool {
	if service == nil || service.Credentials == nil {
		return false
	}

	// Accept both server_url (singular) and server_urls (plural)
	_, hasServerURL := service.Credentials["server_url"]
	_, hasServerURLs := service.Credentials["server_urls"]
	_, hasSecretToken := service.Credentials["secret_token"]

	return (hasServerURL || hasServerURLs) && hasSecretToken
}

// buildConfiguration builds the Elastic APM configuration map
func (e *ElasticApmAgentFramework) buildConfiguration() map[string]string {
	config := make(map[string]string)

	// Default configuration
	config["log_file_name"] = "STDOUT"

	// Add service credentials - accept both server_url (singular) and server_urls (plural)
	if serverURL, ok := e.service.Credentials["server_url"].(string); ok {
		config["server_urls"] = serverURL
	} else if serverURLs, ok := e.service.Credentials["server_urls"].(string); ok {
		config["server_urls"] = serverURLs
	}
	if secretToken, ok := e.service.Credentials["secret_token"].(string); ok {
		config["secret_token"] = secretToken
	}

	// Add service name from application name
	appName := e.getApplicationName()
	if appName != "" {
		config["service_name"] = appName
	}

	// Apply user configuration (any additional credentials override defaults)
	for key, value := range e.service.Credentials {
		if strValue, ok := value.(string); ok {
			config[key] = strValue
		}
	}

	return config
}

// formatSystemProperty formats a key-value pair as a -Delastic.apm.key=value system property
func (e *ElasticApmAgentFramework) formatSystemProperty(key, value string) string {
	// Check if value contains variable substitution (e.g., ${VAR}, $(VAR))
	// If so, we need to escape with \" because this ends up inside JAVA_OPTS which is already quoted
	varPattern := regexp.MustCompile(`\$[({][^)}]+[)}]`)
	if varPattern.MatchString(value) {
		return fmt.Sprintf(`-Delastic.apm.%s=\"%s\"`, key, value)
	}

	// Otherwise, escape for shell
	escapedValue := shellEscape(value)
	return fmt.Sprintf("-Delastic.apm.%s=%s", key, escapedValue)
}

// shellEscape escapes a string for use in shell (similar to Ruby's Shellwords.escape)
func shellEscape(s string) string {
	// If string is safe (alphanumeric, -, _, /, ., :), return as-is
	safePattern := regexp.MustCompile(`^[a-zA-Z0-9_\-/.,:]+$`)
	if safePattern.MatchString(s) {
		return s
	}

	// Otherwise, single-quote and escape single quotes
	escaped := strings.ReplaceAll(s, "'", `'"'"'`)
	return fmt.Sprintf("'%s'", escaped)
}

// getApplicationName returns the application name from VCAP_APPLICATION
func (e *ElasticApmAgentFramework) getApplicationName() string {
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
