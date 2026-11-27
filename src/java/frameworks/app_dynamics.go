package frameworks

import (
	"archive/zip"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/resources"
	"github.com/cloudfoundry/libbuildpack"
)

const (
	appDynamicsAgentDirName         = "app_dynamics_agent"
	appDynamicsAgentDownloadTimeout = 5 * time.Minute
)

var (
	// appDynamicsServicePatterns are the accepted service label/tag/name substrings.
	appDynamicsServicePatterns = []string{"appdynamics", "app-dynamics"}

	// appDynamicsAgentURICredentials are the service credential keys checked for a BYO agent URL.
	// "agent-uri" is the documented key; the rest are accepted aliases.
	appDynamicsAgentURICredentials = []string{
		"agent-uri",
		"agent_uri",
		"agent_url",
		"agent-url",
		"agent-download-url",
		"agent_download_url",
		"customoneagenturl",
	}

	// appDynamicsAppAgentArchives are the archive names accepted from the application itself.
	appDynamicsAppAgentArchives = []string{
		"appdynamics-agent.zip",
		"appdynamics-agent.tar.gz",
		"appdynamics-agent.tgz",
	}

	// appDynamicsAppAgentDirs are application directories that may contain an
	// already-unpacked agent, mirroring the New Relic .new-relic-credentials
	// convention.
	appDynamicsAppAgentDirs = []string{".appdynamics", ".app-dynamics"}
)

// AppDynamicsFramework implements AppDynamics APM agent support
type AppDynamicsFramework struct {
	context *common.Context
}

// NewAppDynamicsFramework creates a new AppDynamics framework instance
func NewAppDynamicsFramework(ctx *common.Context) *AppDynamicsFramework {
	return &AppDynamicsFramework{context: ctx}
}

// Detect checks if AppDynamics should be included
func (a *AppDynamicsFramework) Detect() (string, error) {
	if a.findService() != nil {
		return "AppDynamics Agent", nil
	}

	// Mirror New Relic's file-based detection: an agent vendored in the application
	// can carry its own configuration, so a service binding is not required.
	buildDir := a.context.Stager.BuildDir()
	if findAppVendoredAgentArchive(buildDir) != "" || findAppVendoredAgentDir(buildDir) != "" {
		a.context.Log.Info("AppDynamics agent detected in the application")
		return "AppDynamics Agent", nil
	}

	a.context.Log.Debug("AppDynamics not detected")
	return "", nil
}

// findService returns the first bound AppDynamics service in deterministic order.
func (a *AppDynamicsFramework) findService() *VCAPService {
	services := a.findServices()
	if len(services) == 0 {
		return nil
	}
	return services[0]
}

// findServices returns every bound AppDynamics service, ordered by match
// strength and then by label/index so repeated calls (Detect, Supply, Finalize)
// select the same binding.
func (a *AppDynamicsFramework) findServices() []*VCAPService {
	vcapServices, err := GetVCAPServices()
	if err != nil {
		a.context.Log.Warning("Failed to parse VCAP_SERVICES: %s", err.Error())
		return nil
	}

	return findAppDynamicsServices(vcapServices)
}

type matchedAppDynamicsService struct {
	service *VCAPService
	rank    int
	label   string
	index   int
}

// findAppDynamicsServices matches service labels, names and tags against both
// the "appdynamics" and "app-dynamics" spellings (case-insensitive substrings)
// and returns the strongest matches first.
func findAppDynamicsServices(vcapServices VCAPServices) []*VCAPService {
	labels := make([]string, 0, len(vcapServices))
	for label := range vcapServices {
		labels = append(labels, label)
	}
	sort.Strings(labels)

	var matches []matchedAppDynamicsService
	for _, label := range labels {
		services := vcapServices[label]
		for i := range services {
			rank, ok := appDynamicsServiceRank(label, &services[i])
			if !ok {
				continue
			}
			matches = append(matches, matchedAppDynamicsService{
				service: &services[i],
				rank:    rank,
				label:   label,
				index:   i,
			})
		}
	}

	sort.SliceStable(matches, func(i, j int) bool {
		if matches[i].rank != matches[j].rank {
			return matches[i].rank < matches[j].rank
		}
		if matches[i].label != matches[j].label {
			return matches[i].label < matches[j].label
		}
		return matches[i].index < matches[j].index
	})

	result := make([]*VCAPService, len(matches))
	for i := range matches {
		result[i] = matches[i].service
	}
	return result
}

// appDynamicsServiceRank reports how strongly a binding matches AppDynamics.
// Lower is stronger: exact label (0), label substring (1), name substring (2),
// tag substring (3).
func appDynamicsServiceRank(label string, service *VCAPService) (int, bool) {
	labels := []string{strings.ToLower(label)}
	if service.Label != "" && !strings.EqualFold(service.Label, label) {
		labels = append(labels, strings.ToLower(service.Label))
	}

	for _, pattern := range appDynamicsServicePatterns {
		for _, candidate := range labels {
			if candidate == pattern {
				return 0, true
			}
		}
	}

	for _, pattern := range appDynamicsServicePatterns {
		for _, candidate := range labels {
			if strings.Contains(candidate, pattern) {
				return 1, true
			}
		}
	}

	name := strings.ToLower(service.Name)
	for _, pattern := range appDynamicsServicePatterns {
		if strings.Contains(name, pattern) {
			return 2, true
		}
	}

	for _, tag := range service.Tags {
		tagLower := strings.ToLower(tag)
		for _, pattern := range appDynamicsServicePatterns {
			if strings.Contains(tagLower, pattern) {
				return 3, true
			}
		}
	}

	return 0, false
}

// findAppDynamicsAgent locates the javaagent.jar in the agent directory
func (a *AppDynamicsFramework) findAppDynamicsAgent(agentDir string) (string, error) {
	return FindFileInDirectory(agentDir, "javaagent.jar", []string{"", "ver*"})
}

// Supply installs the AppDynamics agent from a user-provided source.
//
// Sources are tried in order: the "agent-uri" service credential, an archive or
// unpacked agent vendored in the application, then an "appdynamics" dependency in
// manifest.yml (for forked buildpacks, like the IBM JRE).
func (a *AppDynamicsFramework) Supply() error {
	a.context.Log.Debug("Installing AppDynamics Agent")

	agentDir := filepath.Join(a.context.Stager.DepDir(), appDynamicsAgentDirName)

	source, err := a.installAgent(agentDir)
	if err != nil {
		return err
	}

	// Install default configuration from embedded resources
	if err := a.installDefaultConfiguration(agentDir); err != nil {
		a.context.Log.Warning("Could not install default AppDynamics configuration: %s", err.Error())
	}

	if _, err := a.findAppDynamicsAgent(agentDir); err != nil {
		return fmt.Errorf("AppDynamics agent did not contain javaagent.jar: %w", err)
	}

	a.context.Log.Info("Installed AppDynamics Agent from %s", source)
	return nil
}

// installAgent installs the agent from the first usable source and returns a
// human-readable description of it.
func (a *AppDynamicsFramework) installAgent(agentDir string) (string, error) {
	services := a.findServices()

	var uriErr error
	if agentURI, credential := appDynamicsAgentURI(services); agentURI != "" {
		source, err := a.installAgentFromURI(agentURI, credential, agentDir)
		if err == nil {
			return source, nil
		}
		uriErr = err
		a.context.Log.Warning("Could not install AppDynamics agent from service binding credential %q, trying other sources: %s", credential, err.Error())
	}

	if source, ok, err := a.installAgentFromApplication(agentDir); ok {
		if err == nil {
			return source, nil
		}
		if uriErr != nil {
			return "", fmt.Errorf("%v; the application-provided AppDynamics agent also failed: %w", uriErr, err)
		}
		return "", err
	}

	if source, ok, err := a.installAgentFromManifest(agentDir); ok {
		if err == nil {
			return source, nil
		}
		if uriErr != nil {
			return "", fmt.Errorf("%v; the manifest-provided AppDynamics agent also failed: %w", uriErr, err)
		}
		return "", err
	}

	if uriErr != nil {
		return "", fmt.Errorf("AppDynamics agent could not be installed from the service binding and no application-provided or manifest agent was found: %w", uriErr)
	}

	return "", fmt.Errorf(
		"AppDynamics agent not found: provide the agent via the service binding credential 'agent-uri' "+
			"(an http(s) URL to an AppDynamics agent .zip/.tar.gz), vendor one of [%s] in the application root "+
			"or .appdynamics/, or add an 'appdynamics' dependency to a forked buildpack manifest",
		strings.Join(appDynamicsAppAgentArchives, ", "))
}

// installAgentFromURI downloads and extracts an agent archive from a service
// binding credential.
func (a *AppDynamicsFramework) installAgentFromURI(agentURI, credential, agentDir string) (string, error) {
	if err := prepareAppDynamicsAgentDir(agentDir); err != nil {
		return "", err
	}

	archive, err := os.CreateTemp("", "appdynamics-agent-*")
	if err != nil {
		return "", fmt.Errorf("failed to create temporary agent archive: %w", err)
	}
	archivePath := archive.Name()
	if err := archive.Close(); err != nil {
		os.Remove(archivePath)
		return "", fmt.Errorf("failed to close temporary agent archive: %w", err)
	}
	defer os.Remove(archivePath)

	a.context.Log.Info("Downloading AppDynamics agent from %s", redactURL(agentURI))
	if err := downloadAgentArchive(agentURI, archivePath); err != nil {
		return "", fmt.Errorf("failed to download AppDynamics agent from service binding credential %q: %w", credential, err)
	}

	if err := extractAgentArchive(archivePath, agentDir); err != nil {
		return "", fmt.Errorf("failed to extract AppDynamics agent archive: %w", err)
	}

	return fmt.Sprintf("service binding credential %q", credential), nil
}

// installAgentFromApplication installs an agent vendored in the application,
// either as an archive or as an already-unpacked directory.
func (a *AppDynamicsFramework) installAgentFromApplication(agentDir string) (string, bool, error) {
	buildDir := a.context.Stager.BuildDir()

	if archive := findAppVendoredAgentArchive(buildDir); archive != "" {
		if err := prepareAppDynamicsAgentDir(agentDir); err != nil {
			return "", true, err
		}

		a.context.Log.Info("Using application-provided AppDynamics agent archive %s", archive)
		if err := extractAgentArchive(archive, agentDir); err != nil {
			return "", true, fmt.Errorf("failed to extract application-provided AppDynamics agent archive %s: %w", archive, err)
		}

		return fmt.Sprintf("application-provided archive %s", filepath.Base(archive)), true, nil
	}

	if dir := findAppVendoredAgentDir(buildDir); dir != "" {
		if err := prepareAppDynamicsAgentDir(agentDir); err != nil {
			return "", true, err
		}

		a.context.Log.Info("Using application-provided AppDynamics agent directory %s", dir)
		if err := libbuildpack.CopyDirectory(dir, agentDir); err != nil {
			return "", true, fmt.Errorf("failed to copy application-provided AppDynamics agent directory %s: %w", dir, err)
		}

		return fmt.Sprintf("application-provided directory %s", dir), true, nil
	}

	return "", false, nil
}

// installAgentFromManifest installs an "appdynamics" dependency declared in
// manifest.yml. This is the same BYOL path used by the IBM JRE: the upstream
// manifest has no entry, so only forked buildpacks reach this branch.
func (a *AppDynamicsFramework) installAgentFromManifest(agentDir string) (string, bool, error) {
	if len(a.context.Manifest.AllDependencyVersions("appdynamics")) == 0 {
		return "", false, nil
	}

	dep, err := a.context.Manifest.DefaultVersion("appdynamics")
	if err != nil {
		return "", true, fmt.Errorf("manifest.yml declares appdynamics dependencies but no usable default version: %w", err)
	}

	if err := prepareAppDynamicsAgentDir(agentDir); err != nil {
		return "", true, err
	}

	if err := a.context.Installer.InstallDependency(dep, agentDir); err != nil {
		return "", true, fmt.Errorf("failed to install AppDynamics agent from manifest version %s: %w", dep.Version, err)
	}

	return fmt.Sprintf("buildpack manifest (version %s)", dep.Version), true, nil
}

func prepareAppDynamicsAgentDir(agentDir string) error {
	if err := os.RemoveAll(agentDir); err != nil {
		return fmt.Errorf("failed to clear AppDynamics agent directory: %w", err)
	}
	if err := os.MkdirAll(agentDir, 0755); err != nil {
		return fmt.Errorf("failed to create AppDynamics agent directory: %w", err)
	}
	return nil
}

// appDynamicsAgentURI returns the first agent download URL and the credential
// key that supplied it. All bound AppDynamics services are checked, so a
// marketplace binding without a URI does not hide a user-provided one.
func appDynamicsAgentURI(services []*VCAPService) (string, string) {
	for _, service := range services {
		for _, key := range appDynamicsAgentURICredentials {
			value, ok := service.Credentials[key].(string)
			if !ok {
				continue
			}
			if trimmed := strings.TrimSpace(value); trimmed != "" {
				return trimmed, key
			}
		}
	}

	return "", ""
}

// findAppVendoredAgentArchive returns the first AppDynamics agent archive
// shipped with the application.
func findAppVendoredAgentArchive(buildDir string) string {
	for _, name := range appDynamicsAppAgentArchives {
		candidates := []string{
			filepath.Join(buildDir, name),
			filepath.Join(buildDir, ".appdynamics", name),
			filepath.Join(buildDir, ".app-dynamics", name),
		}
		for _, candidate := range candidates {
			info, err := os.Stat(candidate)
			if err == nil && !info.IsDir() {
				return candidate
			}
		}
	}

	return ""
}

// findAppVendoredAgentDir returns an application directory that contains an
// already-unpacked AppDynamics agent.
func findAppVendoredAgentDir(buildDir string) string {
	for _, name := range appDynamicsAppAgentDirs {
		candidate := filepath.Join(buildDir, name)
		info, err := os.Stat(candidate)
		if err != nil || !info.IsDir() {
			continue
		}
		if _, err := FindFileInDirectory(candidate, "javaagent.jar", []string{"", "ver*"}); err == nil {
			return candidate
		}
	}

	return ""
}

// downloadAgentArchive downloads agentURI to dest, supporting URLs with embedded
// HTTP basic authentication.
func downloadAgentArchive(agentURI, dest string) error {
	parsed, err := url.Parse(agentURI)
	if err != nil {
		return fmt.Errorf("invalid agent URL: %w", err)
	}

	request, err := http.NewRequest(http.MethodGet, parsed.String(), nil)
	if err != nil {
		return fmt.Errorf("failed to create agent download request: %w", err)
	}

	if parsed.User != nil {
		password, _ := parsed.User.Password()
		request.SetBasicAuth(parsed.User.Username(), password)
		request.URL.User = nil
	}

	client := &http.Client{Timeout: appDynamicsAgentDownloadTimeout}
	response, err := client.Do(request)
	if err != nil {
		return fmt.Errorf("agent download failed: %w", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		return fmt.Errorf("agent download returned status %d %s", response.StatusCode, http.StatusText(response.StatusCode))
	}

	output, err := os.Create(dest)
	if err != nil {
		return fmt.Errorf("failed to create agent archive: %w", err)
	}

	if _, err := io.Copy(output, response.Body); err != nil {
		output.Close()
		return fmt.Errorf("failed to write agent archive: %w", err)
	}

	if err := output.Close(); err != nil {
		return fmt.Errorf("failed to finish writing agent archive: %w", err)
	}

	return nil
}

// extractAgentArchive extracts a zip, tar.gz or tgz agent archive into dest. The
// format is detected from the file magic first, so a zip named .tar.gz still works.
func extractAgentArchive(archive, dest string) error {
	format, err := detectAgentArchiveFormat(archive)
	if err != nil {
		return err
	}

	switch format {
	case "zip":
		if err := validateZipPaths(archive); err != nil {
			return err
		}
		return libbuildpack.ExtractZip(archive, dest)
	case "tar.gz":
		return libbuildpack.ExtractTarGz(archive, dest)
	default:
		return fmt.Errorf("unsupported agent archive format")
	}
}

// validateZipPaths rejects zip entries that would extract outside the
// destination. ExtractTarGz sanitizes paths itself; ExtractZip does not.
func validateZipPaths(archive string) error {
	reader, err := zip.OpenReader(archive)
	if err != nil {
		return fmt.Errorf("failed to open agent zip: %w", err)
	}
	defer reader.Close()

	for _, entry := range reader.File {
		cleaned := filepath.Clean(entry.Name)
		if cleaned == "." {
			continue
		}
		if filepath.IsAbs(cleaned) || cleaned == ".." || strings.HasPrefix(cleaned, ".."+string(os.PathSeparator)) {
			return fmt.Errorf("agent archive contains an unsafe path: %q", entry.Name)
		}
	}

	return nil
}

func detectAgentArchiveFormat(archive string) (string, error) {
	file, err := os.Open(archive)
	if err != nil {
		return "", fmt.Errorf("failed to open agent archive: %w", err)
	}
	defer file.Close()

	header := make([]byte, 4)
	n, err := io.ReadFull(file, header)
	if err != nil && err != io.ErrUnexpectedEOF && err != io.EOF {
		return "", fmt.Errorf("failed to read agent archive header: %w", err)
	}

	if n >= 2 && header[0] == 'P' && header[1] == 'K' {
		return "zip", nil
	}
	if n >= 2 && header[0] == 0x1f && header[1] == 0x8b {
		return "tar.gz", nil
	}

	switch strings.ToLower(filepath.Ext(archive)) {
	case ".zip":
		return "zip", nil
	case ".gz", ".tgz":
		return "tar.gz", nil
	}

	return "", fmt.Errorf("unable to determine agent archive format: expected .zip, .tar.gz or .tgz")
}

// redactURL removes credentials and query parameters from a URL before logging it.
func redactURL(raw string) string {
	parsed, err := url.Parse(raw)
	if err != nil {
		return "<invalid URL>"
	}
	if parsed.User != nil {
		parsed.User = url.User("REDACTED")
	}
	if parsed.RawQuery != "" {
		parsed.RawQuery = "REDACTED"
	}
	parsed.Fragment = ""
	return parsed.String()
}

// installDefaultConfiguration installs the default app-agent-config.xml from embedded resources
func (a *AppDynamicsFramework) installDefaultConfiguration(agentDir string) error {
	// Create defaults/conf directory structure
	confDir := filepath.Join(agentDir, "defaults", "conf")
	if err := os.MkdirAll(confDir, 0755); err != nil {
		return fmt.Errorf("failed to create conf directory: %w", err)
	}

	configPath := filepath.Join(confDir, "app-agent-config.xml")

	// Check if configuration already exists (user-provided or from external config)
	if _, err := os.Stat(configPath); err == nil {
		a.context.Log.Debug("app-agent-config.xml already exists, skipping default configuration")
		return nil
	}

	// Read embedded app-agent-config.xml
	embeddedPath := "app_dynamics_agent/defaults/conf/app-agent-config.xml"
	configData, err := resources.GetResource(embeddedPath)
	if err != nil {
		return fmt.Errorf("failed to read embedded app-agent-config.xml: %w", err)
	}

	// Write configuration file (no template processing needed for AppDynamics)
	if err := os.WriteFile(configPath, configData, 0644); err != nil {
		return fmt.Errorf("failed to write app-agent-config.xml: %w", err)
	}

	a.context.Log.Debug("Installed default AppDynamics configuration")
	a.context.Log.Debug("  - app-agent-config.xml (agent settings and filters)")
	return nil
}

// Finalize configures AppDynamics agent for runtime
func (a *AppDynamicsFramework) Finalize() error {
	// Get buildpack index for multi-buildpack support
	depsIdx := a.context.Stager.DepsIdx()

	// Find the actual AppDynamics agent jar at staging time
	agentDir := filepath.Join(a.context.Stager.DepDir(), appDynamicsAgentDirName)
	agentJarPath, err := a.findAppDynamicsAgent(agentDir)
	if err != nil {
		return fmt.Errorf("failed to locate javaagent.jar: %w", err)
	}
	a.context.Log.Debug("Found AppDynamics agent at: %s", agentJarPath)

	// Build runtime path using $DEPS_DIR
	relPath, err := filepath.Rel(a.context.Stager.DepDir(), agentJarPath)
	if err != nil {
		return fmt.Errorf("failed to compute relative path: %w", err)
	}
	runtimeAgentPath := filepath.Join(fmt.Sprintf("$DEPS_DIR/%s", depsIdx), relPath)

	// Get AppDynamics configuration from service binding
	service := a.findService()

	// Build javaagent options with runtime path using $DEPS_DIR
	javaOpts := fmt.Sprintf("-javaagent:%s", runtimeAgentPath)

	if service != nil {
		// Add controller host
		if host, ok := service.Credentials["host-name"].(string); ok && host != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.controller.hostName=%s", host)
		}

		// Add controller port
		if port, ok := service.Credentials["port"].(string); ok && port != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.controller.port=%s", port)
		}

		// Add SSL enabled
		if ssl, ok := service.Credentials["ssl-enabled"].(string); ok && ssl != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.controller.ssl.enabled=%s", ssl)
		}

		// Add account name
		if account, ok := service.Credentials["account-name"].(string); ok && account != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.agent.accountName=%s", account)
		}

		// Add account access key
		if accessKey, ok := service.Credentials["account-access-key"].(string); ok && accessKey != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.agent.accountAccessKey=%s", accessKey)
		}

		// Add application name
		if appName, ok := service.Credentials["application-name"].(string); ok && appName != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.agent.applicationName=%s", appName)
		}

		// Add tier name (use app name from VCAP_APPLICATION if not provided)
		if tierName, ok := service.Credentials["tier-name"].(string); ok && tierName != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.agent.tierName=%s", tierName)
		}

		// Add node name (use instance index if available)
		if nodeName, ok := service.Credentials["node-name"].(string); ok && nodeName != "" {
			javaOpts += fmt.Sprintf(" -Dappdynamics.agent.nodeName=%s", nodeName)
		}
	}

	// Write JAVA_OPTS to .opts file with priority 11 (Ruby buildpack line 45)
	if err := writeJavaOptsFile(a.context, 11, "app_dynamics", javaOpts); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	a.context.Log.Info("Configured AppDynamics Agent for runtime (priority 11)")
	return nil
}
