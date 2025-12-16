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
	"archive/zip"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// DatadogJavaagentFramework represents the Datadog APM Java agent framework
type DatadogJavaagentFramework struct {
	context *Context
	jarPath string
}

// NewDatadogJavaagentFramework creates a new Datadog Javaagent framework instance
func NewDatadogJavaagentFramework(ctx *Context) *DatadogJavaagentFramework {
	return &DatadogJavaagentFramework{context: ctx}
}

// Detect checks if Datadog APM should be enabled
func (d *DatadogJavaagentFramework) Detect() (string, error) {
	// Check for DD_API_KEY environment variable
	ddAPIKey := os.Getenv("DD_API_KEY")

	// Also check for datadog service binding
	hasService := false
	vcapServices, err := GetVCAPServices()
	if err == nil {
		// Datadog can be bound as:
		// - "datadog" service (marketplace or label)
		// - Services with "datadog" tag
		// - User-provided services with "datadog" in the name (Docker platform)
		if vcapServices.HasService("datadog") ||
			vcapServices.HasTag("datadog") ||
			vcapServices.HasServiceByNamePattern("datadog") {
			hasService = true
			d.context.Log.Info("Datadog service detected!")
		}
	}

	// Require either DD_API_KEY or service binding
	if ddAPIKey == "" && !hasService {
		d.context.Log.Debug("Datadog Javaagent: DD_API_KEY not set and no service binding found")
		return "", nil
	}

	// Check if APM is explicitly disabled
	ddAPMEnabled := os.Getenv("DD_APM_ENABLED")
	if ddAPMEnabled == "false" {
		d.context.Log.Debug("Datadog Javaagent: DD_APM_ENABLED=false, skipping")
		return "", nil
	}

	d.context.Log.Debug("Datadog Javaagent framework detected")
	return "datadog-javaagent", nil
}

// Supply downloads and installs the Datadog Java agent
func (d *DatadogJavaagentFramework) Supply() error {
	d.context.Log.BeginStep("Installing Datadog Java agent")

	// Note: Datadog buildpack is optional but recommended for full functionality
	if d.hasDatadogBuildpack() {
		d.context.Log.Debug("Datadog buildpack detected - enhanced functionality available")
	}

	// Get dependency from manifest
	dep, err := d.context.Manifest.DefaultVersion("datadog-javaagent")
	if err != nil {
		return fmt.Errorf("unable to find Datadog Javaagent in manifest: %w", err)
	}

	// Install the agent
	datadogDir := filepath.Join(d.context.Stager.DepDir(), "datadog_javaagent")
	if err := d.context.Installer.InstallDependency(dep, datadogDir); err != nil {
		return fmt.Errorf("failed to install Datadog Javaagent: %w", err)
	}

	// Find the installed JAR
	jarPattern := filepath.Join(datadogDir, "dd-java-agent*.jar")
	matches, err := filepath.Glob(jarPattern)
	if err != nil {
		return fmt.Errorf("failed to search for Datadog agent JAR: %w", err)
	}
	if len(matches) == 0 {
		return fmt.Errorf("Datadog agent JAR not found after installation in %s", datadogDir)
	}
	d.jarPath = matches[0]

	// Fix class count (critical for Datadog agent)
	if err := d.fixClassCount(); err != nil {
		d.context.Log.Warning("Failed to fix class count: %s", err)
		// Continue anyway
	}

	d.context.Log.Info("Datadog Java agent %s installed", dep.Version)
	return nil
}

// Finalize configures the Datadog Java agent
func (d *DatadogJavaagentFramework) Finalize() error {
	if d.jarPath == "" {
		return nil
	}

	d.context.Log.BeginStep("Configuring Datadog Java agent")

	// Convert staging path to runtime path
	relPath, err := filepath.Rel(d.context.Stager.DepDir(), d.jarPath)
	if err != nil {
		return fmt.Errorf("failed to determine relative path for Datadog agent: %w", err)
	}
	runtimeJarPath := filepath.Join("$DEPS_DIR/0", relPath)

	// Build all JAVA_OPTS options
	var opts []string
	opts = append(opts, fmt.Sprintf("-javaagent:%s", runtimeJarPath))

	// Set dd.service if DD_SERVICE not set
	if os.Getenv("DD_SERVICE") == "" {
		// Get application name from VCAP_APPLICATION
		appName := d.getApplicationName()
		if appName != "" {
			opts = append(opts, fmt.Sprintf("-Ddd.service=\"%s\"", appName))
		}
	}

	// Set dd.version
	appVersion := d.getApplicationVersion()
	if appVersion != "" {
		opts = append(opts, fmt.Sprintf("-Ddd.version=%s", appVersion))
	}

	// Write all options to .opts file
	javaOpts := strings.Join(opts, " ")
	if err := writeJavaOptsFile(d.context, 18, "datadog_javaagent", javaOpts); err != nil {
		return fmt.Errorf("failed to write JAVA_OPTS for Datadog: %w", err)
	}

	d.context.Log.Info("Datadog Java agent configured")
	return nil
}

// hasDatadogBuildpack checks if the Datadog buildpack is present
func (d *DatadogJavaagentFramework) hasDatadogBuildpack() bool {
	buildDir := d.context.Stager.BuildDir()

	// Check for .datadog or datadog directory
	datadogDirs := []string{
		filepath.Join(buildDir, ".datadog"),
		filepath.Join(buildDir, "datadog"),
	}

	for _, dir := range datadogDirs {
		if _, err := os.Stat(dir); err == nil {
			return true
		}
	}

	return false
}

// fixClassCount creates shadow JAR to fix class counting issue
// Some classes in the Datadog agent are not counted properly by the memory calculator
func (d *DatadogJavaagentFramework) fixClassCount() error {
	// Count .classdata files in the agent JAR
	count, err := d.countClassdataFiles(d.jarPath)
	if err != nil {
		return fmt.Errorf("failed to count classdata files: %w", err)
	}

	if count == 0 {
		// No classdata files, no need to fix
		return nil
	}

	d.context.Log.Debug("Found %d .classdata files in Datadog agent, creating shadow JAR", count)

	// Create temporary directory for fake class files
	tempDir := filepath.Join(d.context.Stager.DepDir(), "datadog_fakeclasses")
	if err := os.MkdirAll(tempDir, 0755); err != nil {
		return fmt.Errorf("failed to create temp directory: %w", err)
	}
	defer os.RemoveAll(tempDir)

	// Create fake .class files (one per classdata file)
	for i := 1; i <= count; i++ {
		classFile := filepath.Join(tempDir, fmt.Sprintf("%d.class", i))
		if err := os.WriteFile(classFile, []byte(strconv.Itoa(i)), 0644); err != nil {
			return fmt.Errorf("failed to create fake class file: %w", err)
		}
	}

	// Create JAR from fake class files
	shadowJAR := filepath.Join(d.context.Stager.DepDir(), "datadog_fakeclasses.jar")
	if err := d.createJAR(tempDir, shadowJAR); err != nil {
		return fmt.Errorf("failed to create shadow JAR: %w", err)
	}

	d.context.Log.Debug("Created shadow JAR with %d fake classes: %s", count, shadowJAR)
	return nil
}

// countClassdataFiles counts .classdata files in a JAR
func (d *DatadogJavaagentFramework) countClassdataFiles(jarPath string) (int, error) {
	r, err := zip.OpenReader(jarPath)
	if err != nil {
		return 0, err
	}
	defer r.Close()

	count := 0
	for _, f := range r.File {
		if strings.HasSuffix(f.Name, ".classdata") {
			count++
		}
	}

	return count, nil
}

// createJAR creates a JAR file from a directory
func (d *DatadogJavaagentFramework) createJAR(sourceDir, jarPath string) error {
	jarFile, err := os.Create(jarPath)
	if err != nil {
		return err
	}
	defer jarFile.Close()

	zipWriter := zip.NewWriter(jarFile)
	defer zipWriter.Close()

	// Walk the source directory
	return filepath.Walk(sourceDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() {
			return nil
		}

		// Get relative path
		relPath, err := filepath.Rel(sourceDir, path)
		if err != nil {
			return err
		}

		// Create ZIP entry
		zipEntry, err := zipWriter.Create(relPath)
		if err != nil {
			return err
		}

		// Write file contents
		fileData, err := os.ReadFile(path)
		if err != nil {
			return err
		}

		_, err = zipEntry.Write(fileData)
		return err
	})
}

// getApplicationName returns the application name from VCAP_APPLICATION
func (d *DatadogJavaagentFramework) getApplicationName() string {
	vcapApp := os.Getenv("VCAP_APPLICATION")
	if vcapApp == "" {
		return ""
	}

	// Parse JSON to get application_name
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
func (d *DatadogJavaagentFramework) getApplicationVersion() string {
	// Check DD_VERSION first
	if version := os.Getenv("DD_VERSION"); version != "" {
		return version
	}

	// Try VCAP_APPLICATION
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
