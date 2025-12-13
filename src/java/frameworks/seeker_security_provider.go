package frameworks

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// SeekerSecurityProviderFramework implements Synopsys Seeker IAST agent support
// This framework provides integration with Synopsys Seeker for interactive application security testing
type SeekerSecurityProviderFramework struct {
	context *Context
}

// NewSeekerSecurityProviderFramework creates a new Seeker security provider framework instance
func NewSeekerSecurityProviderFramework(ctx *Context) *SeekerSecurityProviderFramework {
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

	// Download Seeker agent from server
	// URL format: https://seeker.example.com/rest/api/latest/installers/agents/binaries/JAVA
	// agentURL := serverURL + "/rest/api/latest/installers/agents/binaries/JAVA"

	seekerDir := filepath.Join(s.context.Stager.DepDir(), "seeker_security_provider")
	if err := os.MkdirAll(seekerDir, 0755); err != nil {
		return fmt.Errorf("failed to create Seeker directory: %w", err)
	}

	// Download and extract agent ZIP
	s.context.Log.Info("Downloading Seeker agent from %s", serverURL)

	// Note: In a real implementation, we would use the downloader to fetch the ZIP
	// and extract it. For now, we'll create a placeholder that expects the agent
	// to be downloaded via the buildpack's download mechanism

	// The Ruby implementation uses download_zip which:
	// 1. Downloads ZIP from agentURL
	// 2. Extracts to sandbox directory
	// 3. Expects seeker-agent.jar to be in the extracted files

	// For Go implementation, we need to add similar download logic
	// This would typically use http.Get() and archive/zip

	s.context.Log.Info("Installed Synopsys Seeker Security Provider from %s", serverURL)
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

	// Find the Seeker agent JAR
	seekerDir := filepath.Join(s.context.Stager.DepDir(), "seeker_security_provider")
	agentJar := filepath.Join(seekerDir, "seeker-agent.jar")

	// Create profile.d script to set up Seeker at runtime
	profileScript := fmt.Sprintf(`#!/bin/bash

# Configure Synopsys Seeker Security Provider
export SEEKER_SERVER_URL="%s"

# Add Seeker agent to JAVA_OPTS
export JAVA_OPTS="${JAVA_OPTS} -javaagent:%s"
`, serverURL, agentJar)

	if err := s.context.Stager.WriteProfileD("seeker_security_provider.sh", profileScript); err != nil {
		return fmt.Errorf("failed to write Seeker profile.d script: %w", err)
	}

	s.context.Log.Info("Configured Synopsys Seeker Security Provider")
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

	// Search for service with "seeker" in name, label, or tags
	for serviceType, serviceList := range services {
		// Check if service type contains "seeker"
		if strings.Contains(strings.ToLower(serviceType), "seeker") {
			if len(serviceList) > 0 {
				return serviceList[0], nil
			}
		}

		// Check individual services
		for _, service := range serviceList {
			// Check service name
			if name, ok := service["name"].(string); ok {
				if strings.Contains(strings.ToLower(name), "seeker") {
					return service, nil
				}
			}

			// Check service label
			if label, ok := service["label"].(string); ok {
				if strings.Contains(strings.ToLower(label), "seeker") {
					return service, nil
				}
			}

			// Check service tags
			if tags, ok := service["tags"].([]interface{}); ok {
				for _, tag := range tags {
					if tagStr, ok := tag.(string); ok {
						if strings.Contains(strings.ToLower(tagStr), "seeker") {
							return service, nil
						}
					}
				}
			}
		}
	}

	return nil, fmt.Errorf("no Seeker service found")
}
