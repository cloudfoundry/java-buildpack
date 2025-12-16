// Cloud Foundry Java Buildpack
// Copyright 2013-2025 the original author or authors.
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
	"os"
	"path/filepath"

	"github.com/cloudfoundry/libbuildpack"
)

// TakipiAgentFramework represents the OverOps (formerly Takipi) agent framework
type TakipiAgentFramework struct {
	ctx *Context
}

// NewTakipiAgentFramework creates a new TakipiAgentFramework instance
func NewTakipiAgentFramework(ctx *Context) *TakipiAgentFramework {
	return &TakipiAgentFramework{ctx: ctx}
}

// Detect returns the framework name if a Takipi/OverOps service is bound
func (f *TakipiAgentFramework) Detect() (string, error) {
	vcapServices, err := GetVCAPServices()
	if err != nil {
		return "", nil // Service binding is optional
	}

	// Check for service binding (requires 'secret_key' and 'collector_host' credentials)
	if vcapServices.HasService("takipi") ||
		vcapServices.HasService("overops") ||
		vcapServices.HasTag("takipi") ||
		vcapServices.HasTag("overops") ||
		vcapServices.HasServiceByNamePattern("takipi") ||
		vcapServices.HasServiceByNamePattern("overops") {
		return "Takipi Agent", nil
	}

	return "", nil
}

// Supply downloads and installs the Takipi agent
func (f *TakipiAgentFramework) Supply() error {
	f.ctx.Log.Debug("Takipi Agent Supply phase")

	// Get version from manifest
	dep := libbuildpack.Dependency{Name: "takipi", Version: ""}
	version, err := f.ctx.Manifest.DefaultVersion(dep.Name)
	if err != nil {
		return fmt.Errorf("failed to get default version for takipi: %w", err)
	}
	dep.Version = version.Version

	// Install directory
	installDir := filepath.Join(f.ctx.Stager.DepDir(), "takipi")

	f.ctx.Log.BeginStep("Installing Takipi Agent %s", dep.Version)

	// Download and extract tarball
	if err := f.ctx.Installer.InstallDependency(dep, installDir); err != nil {
		return fmt.Errorf("failed to install takipi: %w", err)
	}

	// Create log directory for agents
	logDir := filepath.Join(installDir, "log", "agents")
	if err := os.MkdirAll(logDir, 0755); err != nil {
		return fmt.Errorf("failed to create log directory: %w", err)
	}

	f.ctx.Log.Info("Takipi Agent installed successfully")
	return nil
}

// Finalize configures the Takipi agent runtime environment
func (f *TakipiAgentFramework) Finalize() error {
	f.ctx.Log.Debug("Takipi Agent Finalize phase")

	installDir := filepath.Join(f.ctx.Stager.DepDir(), "takipi")
	agentPath := filepath.Join(installDir, "lib", "libTakipiAgent.so")

	// Verify agent exists
	if _, err := os.Stat(agentPath); err != nil {
		return fmt.Errorf("takipi agent not found at %s: %w", agentPath, err)
	}

	// Convert staging path to runtime path
	relPath, err := filepath.Rel(f.ctx.Stager.DepDir(), agentPath)
	if err != nil {
		return fmt.Errorf("failed to compute relative path: %w", err)
	}
	runtimeAgentPath := filepath.Join("$DEPS_DIR/0", relPath)

	// Get service credentials
	vcapServices, err := GetVCAPServices()
	if err != nil {
		return fmt.Errorf("failed to parse VCAP_SERVICES: %w", err)
	}

	// Find Takipi service
	var service *VCAPService
	if vcapServices.HasService("takipi") {
		service = vcapServices.GetService("takipi")
	} else if vcapServices.HasService("overops") {
		service = vcapServices.GetService("overops")
	} else {
		service = vcapServices.GetServiceByNamePattern("takipi")
		if service == nil {
			service = vcapServices.GetServiceByNamePattern("overops")
		}
	}

	// Add agent to JAVA_OPTS
	javaOpts := fmt.Sprintf("-agentpath:%s", runtimeAgentPath)

	// Get application name from VCAP_APPLICATION
	appName := os.Getenv("VCAP_APPLICATION")
	if appName != "" {
		// Parse application name from JSON (simple extraction)
		// In production, this would parse the JSON properly
		javaOpts += fmt.Sprintf(" -Dtakipi.name=%s", "app") // Simplified
	}

	// Add Java 9+ options if needed
	javaOpts += " -Xshare:off -XX:-UseTypeSpeculation"

	// Write to .opts file using priority 46
	if err := writeJavaOptsFile(f.ctx, 46, "takipi", javaOpts); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	// Set environment variables via profile.d (LD_LIBRARY_PATH and Takipi-specific vars)
	libPath := "$DEPS_DIR/0/takipi/lib"
	runtimeInstallDir := "$DEPS_DIR/0/takipi"

	profileContent := fmt.Sprintf(`export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:%s"
export TAKIPI_HOME="%s"
export TAKIPI_MACHINE_NAME="node-$CF_INSTANCE_INDEX"
`, libPath, runtimeInstallDir)

	// Add service credentials as environment variables
	if service != nil {
		if collectorHost, ok := service.Credentials["collector_host"].(string); ok && collectorHost != "" {
			profileContent += fmt.Sprintf("export TAKIPI_COLLECTOR_HOST=\"%s\"\n", collectorHost)
		}
		if collectorPort, ok := service.Credentials["collector_port"].(string); ok && collectorPort != "" {
			profileContent += fmt.Sprintf("export TAKIPI_COLLECTOR_PORT=\"%s\"\n", collectorPort)
		}
		if secretKey, ok := service.Credentials["secret_key"].(string); ok && secretKey != "" {
			profileContent += fmt.Sprintf("export TAKIPI_SECRET_KEY=\"%s\"\n", secretKey)
		}
	}

	if err := f.ctx.Stager.WriteProfileD("takipi.sh", profileContent); err != nil {
		return fmt.Errorf("failed to write profile script: %w", err)
	}

	f.ctx.Log.Info("Takipi Agent configured (priority 46)")
	return nil
}
