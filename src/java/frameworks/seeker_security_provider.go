package frameworks

import (
	"encoding/json"
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/libbuildpack"
)

// SeekerSecurityProviderFramework implements Synopsys Seeker IAST agent support
// This framework provides integration with Synopsys Seeker for interactive application security testing
type SeekerSecurityProviderFramework struct {
	context *common.Context
}

// NewSeekerSecurityProviderFramework creates a new Seeker security provider framework instance
func NewSeekerSecurityProviderFramework(ctx *common.Context) *SeekerSecurityProviderFramework {
	return &SeekerSecurityProviderFramework{context: ctx}
}

// Detect checks if Seeker security provider should be included
// Detects when a service with "seeker" in its name/label/tag is bound
func (s *SeekerSecurityProviderFramework) Detect() (string, error) {
	// Check for bound Seeker service in VCAP_SERVICES
	seekerService, err := s.findSeekerService()
	if err != nil {
		return "", nil // Service not found, don't enable
	}

	// Verify required credentials exist
	credentials, ok := seekerService["credentials"].(map[string]interface{})
	if !ok {
		return "", nil
	}

	serverURL, ok := credentials["seeker_server_url"].(string)
	if !ok || serverURL == "" {
		return "", nil
	}

	return "seeker-security-provider", nil
}

// Supply installs the Seeker agent by downloading from Seeker server
func (s *SeekerSecurityProviderFramework) Supply() error {
	s.context.Log.BeginStep("Installing Synopsys Seeker Security Provider")

	// Get Seeker service credentials
	seekerService, err := s.findSeekerService()
	if err != nil {
		return fmt.Errorf("Seeker service not found: %w", err)
	}

	credentials, ok := seekerService["credentials"].(map[string]interface{})
	if !ok {
		return fmt.Errorf("Seeker service credentials not found")
	}

	serverURL, ok := credentials["seeker_server_url"].(string)
	if !ok || serverURL == "" {
		return fmt.Errorf("seeker_server_url not found in service credentials")
	}

	// Construct agent download URL
	// URL format: https://seeker.example.com/rest/api/latest/installers/agents/binaries/JAVA
	agentURL := serverURL + "/rest/api/latest/installers/agents/binaries/JAVA"

	seekerDir := filepath.Join(s.context.Stager.DepDir(), "seeker_security_provider")
	if err := os.MkdirAll(seekerDir, 0755); err != nil {
		return fmt.Errorf("failed to create Seeker directory: %w", err)
	}

	// Download and extract agent ZIP from Seeker server
	s.context.Log.Info("Downloading Seeker agent from %s", agentURL)
	if err := s.downloadAndExtractAgent(agentURL, seekerDir); err != nil {
		return fmt.Errorf("failed to download Seeker agent: %w", err)
	}

	s.context.Log.Info("Installed Synopsys Seeker Security Provider from %s", serverURL)
	return nil
}

// downloadAndExtractAgent downloads the Seeker agent ZIP and extracts it
func (s *SeekerSecurityProviderFramework) downloadAndExtractAgent(agentURL, seekerDir string) error {
	// Create temporary file for download
	tmpFile, err := os.CreateTemp("", "seeker-agent-*.zip")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(tmpFile.Name())
	defer tmpFile.Close()

	// Download the ZIP archive from Seeker server
	resp, err := http.Get(agentURL)
	if err != nil {
		return fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP request failed with status %d", resp.StatusCode)
	}

	// Write response to temp file
	if _, err := io.Copy(tmpFile, resp.Body); err != nil {
		return fmt.Errorf("failed to write agent to temp file: %w", err)
	}
	tmpFile.Close()

	// Extract the ZIP to seekerDir without stripping (strip_top_level = false in Ruby)
	s.context.Log.Info("Extracting Seeker agent to: %s", seekerDir)
	if err := libbuildpack.ExtractZip(tmpFile.Name(), seekerDir); err != nil {
		return fmt.Errorf("failed to extract agent ZIP: %w", err)
	}

	// Verify seeker-agent.jar exists
	agentJar := filepath.Join(seekerDir, "seeker-agent.jar")
	if _, err := os.Stat(agentJar); err != nil {
		return fmt.Errorf("seeker-agent.jar not found in extracted ZIP: %w", err)
	}

	return nil
}

// Finalize configures the Seeker agent for runtime
func (s *SeekerSecurityProviderFramework) Finalize() error {
	// Get Seeker service credentials
	seekerService, err := s.findSeekerService()
	if err != nil {
		return fmt.Errorf("Seeker service not found: %w", err)
	}

	credentials, ok := seekerService["credentials"].(map[string]interface{})
	if !ok {
		return fmt.Errorf("Seeker service credentials not found")
	}

	serverURL, ok := credentials["seeker_server_url"].(string)
	if !ok || serverURL == "" {
		return fmt.Errorf("seeker_server_url not found in service credentials")
	}

	// Get buildpack index for multi-buildpack support
	depsIdx := s.context.Stager.DepsIdx()

	// Build runtime agent path
	agentJar := fmt.Sprintf("$DEPS_DIR/%s/seeker_security_provider/seeker-agent.jar", depsIdx)

	// Build javaagent option
	javaOpts := fmt.Sprintf("-javaagent:%s", agentJar)

	// Write to .opts file using priority 40
	if err := writeJavaOptsFile(s.context, 40, "seeker_security_provider", javaOpts); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	// Set SEEKER_SERVER_URL environment variable via profile.d
	profileScript := fmt.Sprintf(`#!/bin/bash
# Configure Synopsys Seeker Security Provider
export SEEKER_SERVER_URL="%s"
`, serverURL)

	if err := s.context.Stager.WriteProfileD("seeker_security_provider.sh", profileScript); err != nil {
		return fmt.Errorf("failed to write Seeker profile.d script: %w", err)
	}

	s.context.Log.Info("Seeker Security Provider configured (priority 40)")
	return nil
}

// findSeekerService locates the Seeker service in VCAP_SERVICES
func (s *SeekerSecurityProviderFramework) findSeekerService() (map[string]interface{}, error) {
	vcapServices := os.Getenv("VCAP_SERVICES")
	if vcapServices == "" {
		return nil, fmt.Errorf("VCAP_SERVICES not set")
	}

	var services map[string][]map[string]interface{}
	if err := json.Unmarshal([]byte(vcapServices), &services); err != nil {
		return nil, fmt.Errorf("failed to parse VCAP_SERVICES: %w", err)
	}

	for serviceType, serviceList := range services {
		if common.ContainsIgnoreCase(serviceType, "seeker") {
			if len(serviceList) > 0 {
				return serviceList[0], nil
			}
		}

		for _, service := range serviceList {
			if name, ok := service["name"].(string); ok {
				if common.ContainsIgnoreCase(name, "seeker") {
					return service, nil
				}
			}

			if label, ok := service["label"].(string); ok {
				if common.ContainsIgnoreCase(label, "seeker") {
					return service, nil
				}
			}

			if tags, ok := service["tags"].([]interface{}); ok {
				for _, tag := range tags {
					if tagStr, ok := tag.(string); ok {
						if common.ContainsIgnoreCase(tagStr, "seeker") {
							return service, nil
						}
					}
				}
			}
		}
	}

	return nil, fmt.Errorf("no Seeker service found")
}
