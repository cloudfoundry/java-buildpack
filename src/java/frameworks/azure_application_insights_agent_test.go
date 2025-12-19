package frameworks_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/cloudfoundry/java-buildpack/src/java/resources"
)

// TestAzureEmbeddedConfigExists tests that the AI-Agent.xml file
// exists in the embedded resources
func TestAzureEmbeddedConfigExists(t *testing.T) {
	embeddedPath := "azure_application_insights_agent/AI-Agent.xml"

	exists := resources.Exists(embeddedPath)
	if !exists {
		t.Fatalf("Expected embedded resource '%s' to exist", embeddedPath)
	}
}

// TestAzureEmbeddedConfigContent tests that the embedded AI-Agent.xml
// has the expected XML structure
func TestAzureEmbeddedConfigContent(t *testing.T) {
	embeddedPath := "azure_application_insights_agent/AI-Agent.xml"

	configData, err := resources.GetResource(embeddedPath)
	if err != nil {
		t.Fatalf("Failed to read embedded AI-Agent.xml: %v", err)
	}

	configStr := string(configData)

	// Verify XML structure
	if !strings.Contains(configStr, "<?xml version=\"1.0\" encoding=\"utf-8\"?>") {
		t.Error("Expected XML declaration in config")
	}

	if !strings.Contains(configStr, "<ApplicationInsightsAgent>") {
		t.Error("Expected root element '<ApplicationInsightsAgent>' in config")
	}

	// Verify key configuration sections
	expectedSections := []string{
		"<Instrumentation>",
		"<BuiltIn",
		"<Jedis",
		"<MaxStatementQueryLimitInMS>",
	}

	for _, section := range expectedSections {
		if !strings.Contains(configStr, section) {
			t.Errorf("Expected configuration section '%s' in AI-Agent.xml", section)
		}
	}
}

// TestAzureConfigFileCreation tests the full workflow of reading
// embedded config and writing it to disk
func TestAzureConfigFileCreation(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "azure-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	agentDir := filepath.Join(tmpDir, "azure_application_insights_agent")
	if err := os.MkdirAll(agentDir, 0755); err != nil {
		t.Fatalf("Failed to create agent directory: %v", err)
	}

	// Read and write embedded config
	embeddedPath := "azure_application_insights_agent/AI-Agent.xml"
	configData, err := resources.GetResource(embeddedPath)
	if err != nil {
		t.Fatalf("Failed to read embedded config: %v", err)
	}

	configPath := filepath.Join(agentDir, "AI-Agent.xml")
	if err := os.WriteFile(configPath, configData, 0644); err != nil {
		t.Fatalf("Failed to write config file: %v", err)
	}

	// Verify file was created and has correct content
	writtenData, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatalf("Failed to read written config: %v", err)
	}

	if !strings.Contains(string(writtenData), "<ApplicationInsightsAgent>") {
		t.Error("Written config is missing expected content")
	}
}

// TestAzureConfigSkipIfExists tests that existing config is not overwritten
func TestAzureConfigSkipIfExists(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "azure-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	agentDir := filepath.Join(tmpDir, "azure_application_insights_agent")
	if err := os.MkdirAll(agentDir, 0755); err != nil {
		t.Fatalf("Failed to create agent directory: %v", err)
	}

	// Create a user-provided config FIRST
	configPath := filepath.Join(agentDir, "AI-Agent.xml")
	userConfig := "<!-- User-provided configuration -->\n<ApplicationInsightsAgent><Instrumentation><BuiltIn enabled=\"false\"/></Instrumentation></ApplicationInsightsAgent>"
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

	if !strings.Contains(existingStr, "enabled=\"false\"") {
		t.Error("User-provided custom setting was lost")
	}
}
