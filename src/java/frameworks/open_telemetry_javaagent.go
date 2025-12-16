package frameworks

import (
	"fmt"
	"path/filepath"

	"github.com/cloudfoundry/libbuildpack"
)

// OpenTelemetryJavaagentFramework implements OpenTelemetry instrumentation support
type OpenTelemetryJavaagentFramework struct {
	context *Context
}

// NewOpenTelemetryJavaagentFramework creates a new OpenTelemetry Javaagent framework instance
func NewOpenTelemetryJavaagentFramework(ctx *Context) *OpenTelemetryJavaagentFramework {
	return &OpenTelemetryJavaagentFramework{context: ctx}
}

// Detect checks if OpenTelemetry should be included
func (o *OpenTelemetryJavaagentFramework) Detect() (string, error) {
	// Check for OpenTelemetry service binding
	vcapServices, err := GetVCAPServices()
	if err != nil {
		o.context.Log.Warning("Failed to parse VCAP_SERVICES: %s", err.Error())
		return "", nil
	}

	// OpenTelemetry can be bound as:
	// - "otel-collector" service (required by Ruby implementation)
	// - Services with "otel" or "opentelemetry" tag
	// - User-provided services with "otel-collector" in the name (Docker platform)
	if vcapServices.HasService("otel-collector") ||
		vcapServices.HasService("opentelemetry") ||
		vcapServices.HasTag("otel") ||
		vcapServices.HasTag("otel-collector") ||
		vcapServices.HasTag("opentelemetry") ||
		vcapServices.HasServiceByNamePattern("otel-collector") ||
		vcapServices.HasServiceByNamePattern("otel") {
		o.context.Log.Info("OpenTelemetry service detected!")
		return "OpenTelemetry Javaagent", nil
	}

	o.context.Log.Debug("OpenTelemetry not detected")
	return "", nil
}

// Supply installs the OpenTelemetry Javaagent
func (o *OpenTelemetryJavaagentFramework) Supply() error {
	o.context.Log.BeginStep("Installing OpenTelemetry Javaagent")

	// Get OpenTelemetry agent dependency from manifest
	dep, err := o.context.Manifest.DefaultVersion("open-telemetry-javaagent")
	if err != nil {
		o.context.Log.Warning("Unable to determine OpenTelemetry version, using default")
		dep = libbuildpack.Dependency{
			Name:    "open-telemetry-javaagent",
			Version: "2.10.0", // Fallback version
		}
	}

	// Install OpenTelemetry agent JAR
	agentDir := filepath.Join(o.context.Stager.DepDir(), "open_telemetry_javaagent")
	if err := o.context.Installer.InstallDependency(dep, agentDir); err != nil {
		return fmt.Errorf("failed to install OpenTelemetry agent: %w", err)
	}

	o.context.Log.Info("Installed OpenTelemetry Javaagent version %s", dep.Version)
	return nil
}

// Finalize performs final OpenTelemetry configuration
func (o *OpenTelemetryJavaagentFramework) Finalize() error {
	o.context.Log.BeginStep("Configuring OpenTelemetry Javaagent")

	// Find the OpenTelemetry agent JAR
	agentDir := filepath.Join(o.context.Stager.DepDir(), "open_telemetry_javaagent")
	agentJar := filepath.Join(agentDir, "opentelemetry-javaagent.jar")

	// Add javaagent to JAVA_OPTS
	javaOpts := fmt.Sprintf("-javaagent:%s", agentJar)

	// Get OpenTelemetry configuration from service binding
	vcapServices, _ := GetVCAPServices()

	// Try to find service by various patterns
	var service *VCAPService
	if vcapServices.HasService("otel-collector") {
		service = vcapServices.GetService("otel-collector")
	}
	if service == nil && vcapServices.HasService("opentelemetry") {
		service = vcapServices.GetService("opentelemetry")
	}
	if service == nil {
		service = vcapServices.GetServiceByNamePattern("otel-collector")
	}
	if service == nil {
		service = vcapServices.GetServiceByNamePattern("otel")
	}

	// Add all otel.* credentials from the service bind as JVM system properties
	if service != nil && service.Credentials != nil {
		for key, value := range service.Credentials {
			// Only add properties that start with "otel."
			if len(key) >= 5 && key[:5] == "otel." {
				javaOpts += fmt.Sprintf(" -D%s=%v", key, value)
			}
		}

		// Set otel.service.name to the application name if not specified in credentials
		if _, hasServiceName := service.Credentials["otel.service.name"]; !hasServiceName {
			// Use the build directory name as the application name
			appName := filepath.Base(o.context.Stager.BuildDir())
			javaOpts += fmt.Sprintf(" -Dotel.service.name=%s", appName)
		}
	}

	// Append to JAVA_OPTS (preserves values from other frameworks)
	if err := AppendToJavaOpts(o.context, javaOpts); err != nil {
		return fmt.Errorf("failed to set JAVA_OPTS for OpenTelemetry: %w", err)
	}

	o.context.Log.Info("Configured OpenTelemetry Javaagent")
	return nil
}
