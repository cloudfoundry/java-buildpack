package frameworks_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/cloudfoundry/java-buildpack/src/java/resources"
)

// TestAppDynamicsEmbeddedConfigExists tests that the app-agent-config.xml file
// exists in the embedded resources
func TestAppDynamicsEmbeddedConfigExists(t *testing.T) {
	embeddedPath := "app_dynamics_agent/defaults/conf/app-agent-config.xml"

	exists := resources.Exists(embeddedPath)
	if !exists {
		t.Fatalf("Expected embedded resource '%s' to exist", embeddedPath)
	}
}

// TestAppDynamicsEmbeddedConfigContent tests that the embedded app-agent-config.xml
// has the expected XML structure
func TestAppDynamicsEmbeddedConfigContent(t *testing.T) {
	embeddedPath := "app_dynamics_agent/defaults/conf/app-agent-config.xml"

	configData, err := resources.GetResource(embeddedPath)
	if err != nil {
		t.Fatalf("Failed to read embedded app-agent-config.xml: %v", err)
	}

	configStr := string(configData)

	// Verify XML root element
	if !strings.Contains(configStr, "<app-agent-configuration>") {
		t.Error("Expected root element '<app-agent-configuration>' in config")
	}

	// Verify key configuration sections
	expectedSections := []string{
		"<configuration-properties>",
		"<sensitive-url-filters>",
		"<sensitive-data-filters>",
		"<agent-services>",
		"<agent-service name=\"BCIEngine\"",
		"<agent-service name=\"SnapshotService\"",
		"<agent-service name=\"TransactionMonitoringService\"",
	}

	for _, section := range expectedSections {
		if !strings.Contains(configStr, section) {
			t.Errorf("Expected configuration section '%s' in app-agent-config.xml", section)
		}
	}
}

// TestAppDynamicsConfigFileCreation tests the full workflow of reading
// embedded config and writing it to disk
func TestAppDynamicsConfigFileCreation(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "appdynamics-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create agent directory structure (defaults/conf)
	confDir := filepath.Join(tmpDir, "app_dynamics_agent", "defaults", "conf")
	if err := os.MkdirAll(confDir, 0755); err != nil {
		t.Fatalf("Failed to create conf directory: %v", err)
	}

	// Read embedded config
	embeddedPath := "app_dynamics_agent/defaults/conf/app-agent-config.xml"
	configData, err := resources.GetResource(embeddedPath)
	if err != nil {
		t.Fatalf("Failed to read embedded config: %v", err)
	}

	// Write to disk (no template processing needed)
	configPath := filepath.Join(confDir, "app-agent-config.xml")
	if err := os.WriteFile(configPath, configData, 0644); err != nil {
		t.Fatalf("Failed to write config file: %v", err)
	}

	// Verify file was created
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		t.Error("Config file was not created")
	}

	// Read back and verify content
	writtenData, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatalf("Failed to read written config: %v", err)
	}

	writtenStr := string(writtenData)

	// Verify content integrity
	if !strings.Contains(writtenStr, "<app-agent-configuration>") {
		t.Error("Written config is missing root XML element")
	}

	if !strings.Contains(writtenStr, "<agent-service name=\"BCIEngine\"") {
		t.Error("Written config is missing BCIEngine service")
	}
}

// TestAppDynamicsConfigSkipIfExists tests that existing config is not overwritten
func TestAppDynamicsConfigSkipIfExists(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "appdynamics-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	confDir := filepath.Join(tmpDir, "app_dynamics_agent", "defaults", "conf")
	if err := os.MkdirAll(confDir, 0755); err != nil {
		t.Fatalf("Failed to create conf directory: %v", err)
	}

	// Create a user-provided config FIRST
	configPath := filepath.Join(confDir, "app-agent-config.xml")
	userConfig := "<!-- User-provided configuration -->\n<app-agent-configuration><configuration-properties><property name=\"custom\" value=\"true\"/></configuration-properties></app-agent-configuration>"
	if err := os.WriteFile(configPath, []byte(userConfig), 0644); err != nil {
		t.Fatalf("Failed to create user config: %v", err)
	}

	// Simulate the framework's check: if file exists, skip installation
	if _, err := os.Stat(configPath); err == nil {
		t.Log("Config already exists, skipping installation (as expected)")
	} else {
		t.Error("Should have detected existing config file")
	}

	// Verify the user config is still intact
	existingData, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatalf("Failed to read existing config: %v", err)
	}

	existingStr := string(existingData)
	if !strings.Contains(existingStr, "<!-- User-provided configuration -->") {
		t.Error("User-provided config was modified")
	}

	if !strings.Contains(existingStr, "custom") {
		t.Error("User-provided custom property was lost")
	}
}
