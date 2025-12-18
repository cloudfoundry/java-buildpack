package frameworks

import (
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/libbuildpack"
)

// DynatraceFramework implements Dynatrace OneAgent support
type DynatraceFramework struct {
	context   *common.Context
	agentDir  string
	errorFile string
}

// DynatraceManifest represents the manifest.json from Dynatrace API
type DynatraceManifest struct {
	TenantToken            string                 `json:"tenantToken"`
	CommunicationEndpoints []string               `json:"communicationEndpoints"`
	Technologies           map[string]interface{} `json:"technologies"`
}

// NewDynatraceFramework creates a new Dynatrace framework instance
func NewDynatraceFramework(ctx *common.Context) *DynatraceFramework {
	return &DynatraceFramework{
		context:   ctx,
		agentDir:  filepath.Join(ctx.Stager.DepDir(), "dynatrace_one_agent"),
		errorFile: filepath.Join(ctx.Stager.DepDir(), "dynatrace_one_agent", "dynatrace_download_error"),
	}
}

// Detect checks if Dynatrace should be included
func (d *DynatraceFramework) Detect() (string, error) {
	// Check for Dynatrace service binding
	vcapServices, err := GetVCAPServices()
	if err != nil {
		d.context.Log.Warning("Failed to parse VCAP_SERVICES: %s", err.Error())
		return "", nil
	}

	// Dynatrace can be bound as:
	// - "dynatrace" service (marketplace or label)
	// - Services with "dynatrace" tag
	// - User-provided services with "dynatrace" in the name (Docker platform)
	// Ruby requires "apitoken" and "environmentid" credentials for API download
	service := d.getDynatraceService(vcapServices)
	if service != nil {
		if d.hasRequiredCredentials(service) {
			return "Dynatrace OneAgent", nil
		}
		d.context.Log.Warning("Dynatrace service found but missing required credentials (apitoken, environmentid)")
	}

	return "", nil
}

// getDynatraceService returns the Dynatrace service binding
func (d *DynatraceFramework) getDynatraceService(vcapServices VCAPServices) *VCAPService {
	// Try by label first (standard marketplace service)
	if service := vcapServices.GetService("dynatrace"); service != nil {
		return service
	}

	// Try by tag (services tagged with "dynatrace")
	for _, serviceList := range vcapServices {
		for _, service := range serviceList {
			for _, tag := range service.Tags {
				if strings.Contains(strings.ToLower(tag), "dynatrace") {
					return &service
				}
			}
		}
	}

	// Try user-provided services (Docker platform)
	return vcapServices.GetServiceByNamePattern("dynatrace")
}

// hasRequiredCredentials checks if service has required credentials for API download
func (d *DynatraceFramework) hasRequiredCredentials(service *VCAPService) bool {
	apiToken, hasAPIToken := service.Credentials["apitoken"].(string)
	envID, hasEnvID := service.Credentials["environmentid"].(string)
	return hasAPIToken && hasEnvID && apiToken != "" && envID != ""
}

// Supply installs the Dynatrace agent
func (d *DynatraceFramework) Supply() error {
	d.context.Log.BeginStep("Installing Dynatrace OneAgent")

	// Get service binding
	vcapServices, _ := GetVCAPServices()
	service := d.getDynatraceService(vcapServices)

	// Try API download first if credentials are present (Ruby behavior)
	if service != nil && d.hasRequiredCredentials(service) {
		if err := d.downloadFromAPI(service); err != nil {
			// Check if we should skip errors
			if d.shouldSkipErrors(service) {
				d.context.Log.Warning("Dynatrace OneAgent download failed: %s", err.Error())
				d.context.Log.Warning("Agent injection disabled because of skiperrors credential is set to true!")
				// Create error file to skip finalize
				if err := os.MkdirAll(filepath.Dir(d.errorFile), 0755); err == nil {
					os.WriteFile(d.errorFile, []byte(err.Error()), 0644)
				}
				return nil // Don't fail staging
			}
			return fmt.Errorf("failed to download Dynatrace agent from API: %w", err)
		}
		d.context.Log.Info("Downloaded Dynatrace OneAgent from API")
	} else {
		// Fallback to buildpack manifest (current behavior)
		d.context.Log.Info("Using Dynatrace OneAgent from buildpack manifest")
		dep, err := d.context.Manifest.DefaultVersion("dynatrace")
		if err != nil {
			d.context.Log.Warning("Unable to determine Dynatrace version, using default")
			dep = libbuildpack.Dependency{
				Name:    "dynatrace",
				Version: "1.283.0", // Fallback version
			}
		}

		if err := d.context.Installer.InstallDependency(dep, d.agentDir); err != nil {
			return fmt.Errorf("failed to install Dynatrace agent: %w", err)
		}
		d.context.Log.Info("Installed Dynatrace OneAgent version %s from buildpack", dep.Version)
	}

	return nil
}

// downloadFromAPI downloads Dynatrace OneAgent from the Dynatrace API (Ruby behavior)
func (d *DynatraceFramework) downloadFromAPI(service *VCAPService) error {
	apiToken := service.Credentials["apitoken"].(string)

	// Build API URL
	apiBaseURL := d.getAPIBaseURL(service)
	technologies := d.getTechnologies(service)
	downloadURL := fmt.Sprintf("%s/v1/deployment/installer/agent/unix/paas/latest?%s&bitness=64&Api-Token=%s",
		apiBaseURL, technologies, apiToken)

	// Add network zone if specified
	if networkZone, ok := service.Credentials["networkzone"].(string); ok && networkZone != "" {
		downloadURL += fmt.Sprintf("&networkZone=%s", networkZone)
	}

	d.context.Log.Debug("Downloading Dynatrace OneAgent from: %s", strings.Replace(downloadURL, apiToken, "***", -1))

	// Download the agent
	resp, err := http.Get(downloadURL)
	if err != nil {
		return fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP request failed with status %d", resp.StatusCode)
	}

	// Create temporary file
	tmpFile, err := os.CreateTemp("", "dynatrace-agent-*.zip")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(tmpFile.Name())
	defer tmpFile.Close()

	// Write response to temp file
	if _, err := io.Copy(tmpFile, resp.Body); err != nil {
		return fmt.Errorf("failed to write agent to temp file: %w", err)
	}
	tmpFile.Close()

	// Extract the agent
	if err := d.extractAgent(tmpFile.Name()); err != nil {
		return fmt.Errorf("failed to extract agent: %w", err)
	}

	return nil
}

// extractAgent extracts the Dynatrace agent ZIP file
func (d *DynatraceFramework) extractAgent(zipPath string) error {
	// Create agent directory
	if err := os.MkdirAll(d.agentDir, 0755); err != nil {
		return fmt.Errorf("failed to create agent directory: %w", err)
	}

	// Use libbuildpack's unzip utility or system unzip
	cmd := d.context.Command
	if err := cmd.Execute(d.agentDir, os.Stdout, os.Stderr, "unzip", "-qq", zipPath); err != nil {
		return fmt.Errorf("failed to unzip agent: %w", err)
	}

	return nil
}

// getAPIBaseURL returns the Dynatrace API base URL
func (d *DynatraceFramework) getAPIBaseURL(service *VCAPService) string {
	if apiURL, ok := service.Credentials["apiurl"].(string); ok && apiURL != "" {
		return apiURL
	}
	envID := service.Credentials["environmentid"].(string)
	return fmt.Sprintf("https://%s.live.dynatrace.com/api", envID)
}

// getTechnologies returns the technology query parameter for API download
func (d *DynatraceFramework) getTechnologies(service *VCAPService) string {
	codeModules := "include=java"

	if addTech, ok := service.Credentials["addtechnologies"].(string); ok && addTech != "" {
		for _, tech := range strings.Split(addTech, ",") {
			tech = strings.TrimSpace(tech)
			if tech != "" {
				codeModules += fmt.Sprintf("&include=%s", tech)
			}
		}
	}

	return codeModules
}

// shouldSkipErrors checks if we should skip errors during download
func (d *DynatraceFramework) shouldSkipErrors(service *VCAPService) bool {
	if skipErrors, ok := service.Credentials["skiperrors"].(string); ok {
		return skipErrors == "true"
	}
	return false
}

// Finalize performs final Dynatrace configuration
func (d *DynatraceFramework) Finalize() error {
	// Check if download failed and we should skip
	if d.hasDownloadError() {
		d.context.Log.Warning("Dynatrace OneAgent injection disabled due to download error")
		return nil
	}

	// Parse manifest.json
	manifest, err := d.parseManifest()
	if err != nil {
		d.context.Log.Warning("Failed to parse Dynatrace manifest: %s", err.Error())
		return nil // Don't fail finalize
	}

	// Get service binding
	vcapServices, _ := GetVCAPServices()
	service := d.getDynatraceService(vcapServices)

	// Set LD_PRELOAD environment variable
	agentPath := d.getAgentPath(manifest)
	if agentPath != "" {
		if err := d.context.Stager.WriteEnvFile("LD_PRELOAD", agentPath); err != nil {
			d.context.Log.Warning("Failed to set LD_PRELOAD: %s", err.Error())
		}
	}

	// Handle FIPS mode
	if service != nil && d.shouldEnableFIPS(service) {
		fipsFlag := filepath.Join(d.agentDir, "agent", "dt_fips_disabled.flag")
		if err := os.Remove(fipsFlag); err != nil && !os.IsNotExist(err) {
			d.context.Log.Warning("Failed to enable FIPS mode: %s", err.Error())
		}
	}

	// Set Dynatrace environment variables
	if err := d.setDynatraceEnvironmentVariables(manifest, service); err != nil {
		d.context.Log.Warning("Failed to set Dynatrace environment variables: %s", err.Error())
	}

	return nil
}

// hasDownloadError checks if an error file exists from failed download
func (d *DynatraceFramework) hasDownloadError() bool {
	if _, err := os.Stat(d.errorFile); err == nil {
		if content, err := os.ReadFile(d.errorFile); err == nil {
			d.context.Log.Warning("Download error: %s", string(content))
		}
		return true
	}
	return false
}

// parseManifest parses the Dynatrace manifest.json file
func (d *DynatraceFramework) parseManifest() (*DynatraceManifest, error) {
	manifestPath := filepath.Join(d.agentDir, "manifest.json")

	data, err := os.ReadFile(manifestPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read manifest: %w", err)
	}

	var manifest DynatraceManifest
	if err := json.Unmarshal(data, &manifest); err != nil {
		return nil, fmt.Errorf("failed to parse manifest JSON: %w", err)
	}

	return &manifest, nil
}

// getAgentPath returns the path to the Dynatrace agent library from manifest
func (d *DynatraceFramework) getAgentPath(manifest *DynatraceManifest) string {
	if manifest == nil {
		// Fallback to default path
		return filepath.Join(d.agentDir, "agent", "lib64", "liboneagentproc.so")
	}

	// Parse technologies.process.linux-x86-64 array to find primary binary
	if technologies, ok := manifest.Technologies["process"].(map[string]interface{}); ok {
		if linuxBinaries, ok := technologies["linux-x86-64"].([]interface{}); ok {
			for _, bin := range linuxBinaries {
				if binary, ok := bin.(map[string]interface{}); ok {
					if binaryType, ok := binary["binarytype"].(string); ok && binaryType == "primary" {
						if path, ok := binary["path"].(string); ok {
							return filepath.Join(d.agentDir, path)
						}
					}
				}
			}
		}
	}

	// Fallback to default path
	return filepath.Join(d.agentDir, "agent", "lib64", "liboneagentproc.so")
}

// setDynatraceEnvironmentVariables sets Dynatrace-specific environment variables
func (d *DynatraceFramework) setDynatraceEnvironmentVariables(manifest *DynatraceManifest, service *VCAPService) error {
	if service == nil || manifest == nil {
		return nil
	}

	// DT_TENANT - Environment ID
	if envID, ok := service.Credentials["environmentid"].(string); ok && envID != "" {
		d.context.Stager.WriteEnvFile("DT_TENANT", envID)
	}

	// DT_TENANTTOKEN - From manifest
	if manifest.TenantToken != "" {
		d.context.Stager.WriteEnvFile("DT_TENANTTOKEN", manifest.TenantToken)
	}

	// DT_CONNECTION_POINT - Communication endpoints from manifest
	if len(manifest.CommunicationEndpoints) > 0 {
		endpoints := strings.Join(manifest.CommunicationEndpoints, ";")
		d.context.Stager.WriteEnvFile("DT_CONNECTION_POINT", fmt.Sprintf(`"%s"`, endpoints))
	}

	// DT_APPLICATIONID - Application name (if not already set)
	if !d.isEnvVarSet("DT_APPLICATIONID") {
		if appName := d.getApplicationName(); appName != "" {
			d.context.Stager.WriteEnvFile("DT_APPLICATIONID", appName)
		}
	}

	// DT_NETWORK_ZONE - Network zone (if specified)
	if networkZone, ok := service.Credentials["networkzone"].(string); ok && networkZone != "" {
		d.context.Stager.WriteEnvFile("DT_NETWORK_ZONE", networkZone)
	}

	// DT_LOGSTREAM - Set to stdout (if not already set)
	if !d.isEnvVarSet("DT_LOGSTREAM") {
		d.context.Stager.WriteEnvFile("DT_LOGSTREAM", "stdout")
	}

	return nil
}

// shouldEnableFIPS checks if FIPS mode should be enabled
func (d *DynatraceFramework) shouldEnableFIPS(service *VCAPService) bool {
	if enableFIPS, ok := service.Credentials["enablefips"].(string); ok {
		return enableFIPS == "true"
	}
	return false
}

// getApplicationName returns the application name from VCAP_APPLICATION
func (d *DynatraceFramework) getApplicationName() string {
	vcapAppStr := os.Getenv("VCAP_APPLICATION")
	if vcapAppStr == "" {
		return ""
	}

	var vcapApp map[string]interface{}
	if err := json.Unmarshal([]byte(vcapAppStr), &vcapApp); err != nil {
		return ""
	}

	if appName, ok := vcapApp["application_name"].(string); ok {
		return appName
	}

	return ""
}

// isEnvVarSet checks if an environment variable is already set
func (d *DynatraceFramework) isEnvVarSet(envVar string) bool {
	return os.Getenv(envVar) != ""
}
