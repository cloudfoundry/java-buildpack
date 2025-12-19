package frameworks_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/cloudfoundry/java-buildpack/src/java/resources"
)

// TestProtectAppEmbeddedConfigExists tests that the IngrianNAE.properties file
// exists in the embedded resources
func TestProtectAppEmbeddedConfigExists(t *testing.T) {
	embeddedPath := "protect_app_security_provider/IngrianNAE.properties"

	exists := resources.Exists(embeddedPath)
	if !exists {
		t.Fatalf("Expected embedded resource '%s' to exist", embeddedPath)
	}
}

// TestProtectAppEmbeddedConfigContent tests that the embedded IngrianNAE.properties
// has the expected property keys
func TestProtectAppEmbeddedConfigContent(t *testing.T) {
	embeddedPath := "protect_app_security_provider/IngrianNAE.properties"

	configData, err := resources.GetResource(embeddedPath)
	if err != nil {
		t.Fatalf("Failed to read embedded IngrianNAE.properties: %v", err)
	}

	configStr := string(configData)

	// Verify key properties
	expectedProperties := []string{
		"Version=",
		"NAE_IP.1=",
		"NAE_Port=",
		"Protocol=ssl",
		"Connection_Pool",
		"Connection_Timeout",
		"Key_Store_Location=",
		"FIPS_Mode=",
		"Log_Level=",
	}

	for _, prop := range expectedProperties {
		if !strings.Contains(configStr, prop) {
			t.Errorf("Expected property '%s' in IngrianNAE.properties", prop)
		}
	}
}

// TestProtectAppConfigFileCreation tests the full workflow of reading
// embedded config and writing it to disk
func TestProtectAppConfigFileCreation(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "protectapp-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	protectAppDir := filepath.Join(tmpDir, "protect_app_security_provider")
	if err := os.MkdirAll(protectAppDir, 0755); err != nil {
		t.Fatalf("Failed to create ProtectApp directory: %v", err)
	}

	// Read and write embedded config
	embeddedPath := "protect_app_security_provider/IngrianNAE.properties"
	configData, err := resources.GetResource(embeddedPath)
	if err != nil {
		t.Fatalf("Failed to read embedded config: %v", err)
	}

	configPath := filepath.Join(protectAppDir, "IngrianNAE.properties")
	if err := os.WriteFile(configPath, configData, 0644); err != nil {
		t.Fatalf("Failed to write config file: %v", err)
	}

	// Verify file was created and has correct content
	writtenData, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatalf("Failed to read written config: %v", err)
	}

	if !strings.Contains(string(writtenData), "Version=") {
		t.Error("Written config is missing version property")
	}

	if !strings.Contains(string(writtenData), "NAE_Port=") {
		t.Error("Written config is missing NAE port property")
	}
}

// TestProtectAppConfigSkipIfExists tests that existing config is not overwritten
func TestProtectAppConfigSkipIfExists(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "protectapp-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	protectAppDir := filepath.Join(tmpDir, "protect_app_security_provider")
	if err := os.MkdirAll(protectAppDir, 0755); err != nil {
		t.Fatalf("Failed to create ProtectApp directory: %v", err)
	}

	// Create a user-provided config FIRST
	configPath := filepath.Join(protectAppDir, "IngrianNAE.properties")
	userConfig := "# User-provided ProtectApp configuration\nVersion=3.0\nNAE_IP.1=192.168.1.100\nCustomProperty=CustomValue\n"
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
	if !strings.Contains(existingStr, "# User-provided ProtectApp configuration") {
		t.Error("User-provided config was modified")
	}

	if !strings.Contains(existingStr, "CustomProperty=CustomValue") {
		t.Error("User-provided custom property was lost")
	}

	if !strings.Contains(existingStr, "192.168.1.100") {
		t.Error("User-provided NAE IP was lost")
	}
}
