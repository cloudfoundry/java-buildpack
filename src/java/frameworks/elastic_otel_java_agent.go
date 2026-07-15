// Cloud Foundry Java Buildpack
// Copyright 2013-2026 the original author or authors.
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

	"github.com/cloudfoundry/java-buildpack/src/java/common"
)

// ElasticOtelJavaAgentFramework represents the Elastic Distribution of OpenTelemetry Java agent framework.
type ElasticOtelJavaAgentFramework struct {
	context *common.Context
	jarPath string
	service *common.VCAPService
}

// NewElasticOtelJavaAgentFramework creates a new Elastic OTel Java agent framework instance.
func NewElasticOtelJavaAgentFramework(ctx *common.Context) *ElasticOtelJavaAgentFramework {
	return &ElasticOtelJavaAgentFramework{context: ctx}
}

// Detect checks if the Elastic OTel Java agent should be enabled.
func (e *ElasticOtelJavaAgentFramework) Detect() (string, error) {
	if os.Getenv("ELASTIC_OTEL_AGENT") != "" {
		e.context.Log.Debug("Elastic OTel Java agent framework detected via ELASTIC_OTEL_AGENT")
		return "elastic-otel-javaagent", nil
	}
	if os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") != "" && os.Getenv("OTEL_EXPORTER_OTLP_HEADERS") != "" {
		e.context.Log.Debug("Elastic OTel Java agent framework detected via OTLP environment variables")
		return "elastic-otel-javaagent", nil
	}

	service := e.findElasticOtelService()
	if service == nil {
		e.context.Log.Debug("Elastic OTel Java agent: no elastic-otel service found")
		return "", nil
	}
	if !e.hasRequiredCredentials(service) {
		e.context.Log.Debug("Elastic OTel Java agent: service missing OTLP endpoint or authentication credentials")
		return "", nil
	}

	e.service = service
	e.context.Log.Debug("Elastic OTel Java agent framework detected")
	return "elastic-otel-javaagent", nil
}

// Supply downloads and installs the Elastic OTel Java agent.
func (e *ElasticOtelJavaAgentFramework) Supply() error {
	e.context.Log.Debug("Installing Elastic OTel Java agent")

	dep, err := e.context.Manifest.DefaultVersion(e.DependencyIdentifier())
	if err != nil {
		return fmt.Errorf("unable to find Elastic OTel Java agent in manifest: %w", err)
	}

	agentDir := filepath.Join(e.context.Stager.DepDir(), "elastic_otel_java_agent")
	if err := e.context.Installer.InstallDependency(dep, agentDir); err != nil {
		return fmt.Errorf("failed to install Elastic OTel Java agent: %w", err)
	}
	if err := e.constructJarPath(agentDir); err != nil {
		return fmt.Errorf("elastic OTel Java agent JAR path not found during supply: %w", err)
	}

	e.context.Log.Info("Elastic OTel Java agent %s installed", dep.Version)
	return nil
}

// Finalize configures the Elastic OTel Java agent.
func (e *ElasticOtelJavaAgentFramework) Finalize() error {
	agentDir := filepath.Join(e.context.Stager.DepDir(), "elastic_otel_java_agent")
	if err := e.constructJarPath(agentDir); err != nil {
		return fmt.Errorf("elastic OTel Java agent JAR path not found during finalize: %w", err)
	}

	e.context.Log.BeginStep("Configuring Elastic OTel Java agent")

	relPath, err := filepath.Rel(e.context.Stager.DepDir(), e.jarPath)
	if err != nil {
		return fmt.Errorf("failed to determine relative path for Elastic OTel Java agent: %w", err)
	}
	runtimeJarPath := filepath.Join(fmt.Sprintf("$DEPS_DIR/%s", e.context.Stager.DepsIdx()), relPath)

	config := e.buildConfiguration()
	opts := []string{fmt.Sprintf("-javaagent:%s", runtimeJarPath)}
	for key, value := range config {
		opts = append(opts, formatJavaSystemProperty(key, value))
	}

	if err := writeJavaOptsFile(e.context, 44, "elastic_otel_java_agent", strings.Join(opts, " ")); err != nil {
		return fmt.Errorf("failed to write JAVA_OPTS for Elastic OTel Java agent: %w", err)
	}

	e.context.Log.Debug("Elastic OTel Java agent configured")
	return nil
}

func (e *ElasticOtelJavaAgentFramework) findElasticOtelService() *common.VCAPService {
	vcapServices, err := GetVCAPServices()
	if err != nil {
		e.context.Log.Warning("Failed to parse VCAP_SERVICES: %s", err.Error())
		return nil
	}

	for _, label := range []string{"elastic-otel", "edot-java", "elastic-edot"} {
		if service := vcapServices.GetService(label); service != nil {
			return service
		}
	}
	for _, services := range vcapServices {
		for _, service := range services {
			if hasAnyTag(service, "elastic-otel", "edot-java", "elastic-edot") ||
				common.ContainsIgnoreCase(service.Name, "elastic-otel") ||
				common.ContainsIgnoreCase(service.Name, "edot-java") ||
				common.ContainsIgnoreCase(service.Name, "elastic-edot") {
				return &service
			}
		}
	}

	return nil
}

func (e *ElasticOtelJavaAgentFramework) hasRequiredCredentials(service *common.VCAPService) bool {
	if service == nil || service.Credentials == nil {
		return false
	}
	return getOtlpEndpoint(service.Credentials) != "" && getOtlpHeaders(service.Credentials) != ""
}

func (e *ElasticOtelJavaAgentFramework) buildConfiguration() map[string]string {
	config := map[string]string{}
	if service := e.findElasticOtelService(); service != nil {
		e.service = service
		for key, value := range service.Credentials {
			strValue, ok := value.(string)
			if !ok || strValue == "" {
				continue
			}
			if strings.HasPrefix(key, "otel.") || strings.HasPrefix(key, "elastic.otel.") {
				config[key] = strValue
			}
		}
		if endpoint := getOtlpEndpoint(service.Credentials); endpoint != "" {
			config["otel.exporter.otlp.endpoint"] = endpoint
		}
		if headers := getOtlpHeaders(service.Credentials); headers != "" {
			config["otel.exporter.otlp.headers"] = headers
		}
	}

	if endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"); endpoint != "" {
		config["otel.exporter.otlp.endpoint"] = endpoint
	}
	if headers := os.Getenv("OTEL_EXPORTER_OTLP_HEADERS"); headers != "" {
		config["otel.exporter.otlp.headers"] = headers
	}
	if serviceName := os.Getenv("OTEL_SERVICE_NAME"); serviceName != "" {
		config["otel.service.name"] = serviceName
	}
	if _, ok := config["otel.service.name"]; !ok {
		if appName := GetApplicationName(false); appName != "" {
			config["otel.service.name"] = appName
		}
	}
	if _, ok := config["otel.resource.attributes"]; !ok {
		if spaceName := getSpaceName(); spaceName != "" {
			config["otel.resource.attributes"] = "deployment.environment.name=" + spaceName
		}
	}

	return config
}

func getOtlpEndpoint(credentials map[string]interface{}) string {
	for _, key := range []string{"otel.exporter.otlp.endpoint", "otlp_endpoint", "otlpEndpoint", "endpoint"} {
		if value, ok := credentials[key].(string); ok && value != "" {
			return value
		}
	}
	return ""
}

func getOtlpHeaders(credentials map[string]interface{}) string {
	if value, ok := credentials["otel.exporter.otlp.headers"].(string); ok && value != "" {
		return value
	}
	if value, ok := credentials["api_key"].(string); ok && value != "" {
		return "Authorization=ApiKey " + value
	}
	if value, ok := credentials["secret_token"].(string); ok && value != "" {
		return "Authorization=Bearer " + value
	}
	if value, ok := credentials["access_token"].(string); ok && value != "" {
		return "Authorization=Bearer " + value
	}
	return ""
}

func formatJavaSystemProperty(key, value string) string {
	return fmt.Sprintf("-D%s=%s", key, shellEscape(value))
}

func hasAnyTag(service common.VCAPService, tags ...string) bool {
	for _, actual := range service.Tags {
		for _, expected := range tags {
			if strings.EqualFold(actual, expected) {
				return true
			}
		}
	}
	return false
}

func getSpaceName() string {
	vcapApp := os.Getenv("VCAP_APPLICATION")
	if vcapApp == "" {
		return ""
	}
	var appData map[string]interface{}
	if err := json.Unmarshal([]byte(vcapApp), &appData); err != nil {
		return ""
	}
	if spaceName, ok := appData["space_name"].(string); ok {
		return spaceName
	}
	return ""
}

func (e *ElasticOtelJavaAgentFramework) constructJarPath(agentDir string) error {
	jarPattern := filepath.Join(agentDir, e.DependencyIdentifier()+"*.jar")
	matches, err := filepath.Glob(jarPattern)
	if err != nil {
		return fmt.Errorf("failed to search for Elastic OTel javaagent jar: %w", err)
	}
	if len(matches) == 0 {
		return fmt.Errorf("elastic OTel Java agent jar not found after installation in %s", agentDir)
	}
	e.jarPath = matches[0]
	return nil
}

func (e *ElasticOtelJavaAgentFramework) DependencyIdentifier() string {
	return "elastic-otel-javaagent"
}
