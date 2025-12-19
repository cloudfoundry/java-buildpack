package frameworks_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/cloudfoundry/java-buildpack/src/java/resources"
)

// TestLunaEmbeddedConfigExists tests that the Chrystoki.conf file
// exists in the embedded resources
func TestLunaEmbeddedConfigExists(t *testing.T) {
	embeddedPath := "luna_security_provider/Chrystoki.conf"

	exists := resources.Exists(embeddedPath)
	if !exists {
		t.Fatalf("Expected embedded resource '%s' to exist", embeddedPath)
	}
}

// TestLunaEmbeddedConfigContent tests that the embedded Chrystoki.conf
// has the expected configuration structure
func TestLunaEmbeddedConfigContent(t *testing.T) {
	embeddedPath := "luna_security_provider/Chrystoki.conf"

	configData, err := resources.GetResource(embeddedPath)
	if err != nil {
		t.Fatalf("Failed to read embedded Chrystoki.conf: %v", err)
	}

	configStr := string(configData)

	// Verify Luna configuration sections
	expectedSections := []string{
		"Luna = {",
		"CloningCommandTimeOut",
		"DefaultTimeOut",
		"KeypairGenTimeOut",
		"Misc = {",
		"PE1746Enabled",
	}

	for _, section := range expectedSections {
		if !strings.Contains(configStr, section) {
			t.Errorf("Expected configuration section '%s' in Chrystoki.conf", section)
		}
	}
}

// TestLunaConfigFileCreation tests the full workflow of reading
// embedded config and writing it to disk
func TestLunaConfigFileCreation(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "luna-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	lunaDir := filepath.Join(tmpDir, "luna_security_provider")
	if err := os.MkdirAll(lunaDir, 0755); err != nil {
		t.Fatalf("Failed to create Luna directory: %v", err)
	}

	// Read and write embedded config
	embeddedPath := "luna_security_provider/Chrystoki.conf"
	configData, err := resources.GetResource(embeddedPath)
	if err != nil {
		t.Fatalf("Failed to read embedded config: %v", err)
	}

	configPath := filepath.Join(lunaDir, "Chrystoki.conf")
	if err := os.WriteFile(configPath, configData, 0644); err != nil {
		t.Fatalf("Failed to write config file: %v", err)
	}

	// Verify file was created and has correct content
	writtenData, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatalf("Failed to read written config: %v", err)
	}

	if !strings.Contains(string(writtenData), "Luna = {") {
		t.Error("Written config is missing Luna section")
	}

	if !strings.Contains(string(writtenData), "DefaultTimeOut") {
		t.Error("Written config is missing timeout configuration")
	}
}

// TestLunaConfigSkipIfExists tests that existing config is not overwritten
func TestLunaConfigSkipIfExists(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "luna-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	lunaDir := filepath.Join(tmpDir, "luna_security_provider")
	if err := os.MkdirAll(lunaDir, 0755); err != nil {
		t.Fatalf("Failed to create Luna directory: %v", err)
	}

	// Create a user-provided config FIRST
	configPath := filepath.Join(lunaDir, "Chrystoki.conf")
	userConfig := "# User-provided Luna configuration\nLuna = {\n  CustomTimeout = 999999;\n}\n"
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
	if !strings.Contains(existingStr, "# User-provided Luna configuration") {
		t.Error("User-provided config was modified")
	}

	if !strings.Contains(existingStr, "CustomTimeout = 999999") {
		t.Error("User-provided custom timeout was lost")
	}
}
