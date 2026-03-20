package dynatrace

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"time"

	"github.com/cloudfoundry/libbuildpack"
)

// Command is an interface around libbuildpack.Command. Represents an executor for external command calls. We have it
// as an interface so that we can mock it and use in the unit tests.
type Command interface {
	Execute(string, io.Writer, io.Writer, string, ...string) error
}

// credentials represent the user settings extracted from the environment.
type credentials struct {
	ServiceName       string
	EnvironmentID     string
	CustomOneAgentURL string
	APIToken          string
	APIURL            string
	SkipErrors        bool
	NetworkZone       string
	EnableFIPS        bool
	AddTechnologies   string
}

// Hook implements libbuildpack.Hook. It downloads and install the Dynatrace OneAgent.
type Hook struct {
	libbuildpack.DefaultHook
	Log     *libbuildpack.Logger
	Command Command

	// IncludeTechnologies is used to indicate the technologies we want to download agents for.
	IncludeTechnologies []string

	// MaxDownloadRetries is the maximum number of retries the hook will try to download the agent if they fail.
	MaxDownloadRetries int
}

// NewHook returns a libbuildpack.Hook instance for integrating monitoring with Dynatrace. The technology names for the
// agents to download can be set as parameters.
func NewHook(technologies ...string) libbuildpack.Hook {
	return &Hook{
		Log:                 libbuildpack.NewLogger(os.Stdout),
		Command:             &libbuildpack.Command{},
		IncludeTechnologies: technologies,
		MaxDownloadRetries:  3,
	}
}

// AfterCompile downloads and installs the Dynatrace agent.
func (h *Hook) AfterCompile(stager *libbuildpack.Stager) error {
	// All other methods in this package are called  from here, which
	// makes it the main entry-point.

	var err error

	h.Log.Debug("Checking for enabled dynatrace service...")

	// Get credentials...
	creds := h.getCredentials()
	if creds == nil {
		h.Log.Debug("Dynatrace service credentials not found!")
		return nil
	}

	h.Log.Info("Dynatrace service credentials found. Setting up Dynatrace OneAgent.")

	installDir := filepath.Join("dynatrace", "oneagent")

	// download installer
	var installerFilename string
	if runtime.GOOS == "linux" {
		installerFilename = "paasInstaller.sh"
	} else if runtime.GOOS == "windows" {
		installerFilename = "paasInstaller.zip"
	} else {
		// This is the only place where we need to return an error.
		// All following operating system checks are just to determine installation specifics.
		return errors.New("libbuildpack-dynatrace: Unsupported operating system: " + runtime.GOOS)
	}

	installerFilePath := filepath.Join(os.TempDir(), installerFilename)
	url := h.getDownloadURL(creds)
	err = h.download(url, installerFilePath, stager, creds)
	if err != nil && creds.SkipErrors {
		h.Log.Warning("Error during installer download, skipping installation")
		return nil
	}else if err != nil {
		return err
	}

	// run installer
	if runtime.GOOS == "linux" {
		err = h.runInstallerUnix(installerFilePath, installDir, creds, stager)
	} else if runtime.GOOS == "windows" {
		err = h.runInstallerWindows(installerFilePath, installDir, creds, stager)
	}

	// update agent config
	h.Log.Debug("Fetching updated OneAgent configuration from tenant... ")
	configDir := filepath.Join(stager.BuildDir(), installDir)
	if err := h.updateAgentConfig(creds, configDir, stager); err != nil {
		if creds.SkipErrors {
			h.Log.Warning("Error during agent config update, skipping it")
			return nil
		}
		h.Log.Error("Error during agent config update: %s", err)
		return err

	}

	if h.getCredentials().EnableFIPS {
		h.Log.Debug("Removing file 'dt_fips_disabled.flag' to enable FIPS mode...")
		flagFilePath := filepath.Join(stager.BuildDir(), installDir, "agent", "dt_fips_disabled.flag")
		if err := os.Remove(flagFilePath); err != nil {
			h.Log.Error("Error during fips flag file deletion: %s", err)
			return err
		}
	}

	h.Log.Info("Dynatrace OneAgent injection is set up.")
	return nil
}

// getCredentials returns the configuration from the environment, or nil if not found. The credentials are represented
// as a JSON object in the VCAP_SERVICES environment variable.
func (h *Hook) getCredentials() *credentials {
	// Represent the structure of the JSON object in VCAP_SERVICES for parsing.

	var vcapServices map[string][]struct {
		Name        string                 `json:"name"`
		Credentials map[string]interface{} `json:"credentials"`
	}

	if err := json.Unmarshal([]byte(os.Getenv("VCAP_SERVICES")), &vcapServices); err != nil {
		h.Log.Debug("Failed to unmarshal VCAP_SERVICES: %s", err)
		return nil
	}

	var found []*credentials

	for _, services := range vcapServices {
		for _, service := range services {
			if !strings.Contains(strings.ToLower(service.Name), "dynatrace") {
				continue
			}

			queryString := func(key string) string {
				if value, ok := service.Credentials[key].(string); ok {
					return value
				}
				return ""
			}

			creds := &credentials{
				ServiceName:       service.Name,
				EnvironmentID:     queryString("environmentid"),
				APIToken:          queryString("apitoken"),
				APIURL:            queryString("apiurl"),
				CustomOneAgentURL: queryString("customoneagenturl"),
				SkipErrors:        queryString("skiperrors") == "true",
				NetworkZone:       queryString("networkzone"),
				EnableFIPS:        queryString("enablefips") == "true",
				AddTechnologies:      queryString("addtechnologies"),
			}

			if (creds.EnvironmentID != "" && creds.APIToken != "") || creds.CustomOneAgentURL != "" {
				found = append(found, creds)
			} else if !(creds.EnvironmentID == "" && creds.APIToken == "") { // One of the fields is empty.
				h.Log.Warning("Incomplete credentials for service: %s, environment ID: %s, API token: %s", creds.ServiceName,
					creds.EnvironmentID, creds.APIToken)
			}
		}
	}

	if len(found) == 1 {
		h.Log.Debug("Found one matching service: %s", found[0].ServiceName)
		return found[0]
	}

	if len(found) > 1 {
		h.Log.Warning("More than one matching service found!")
	}

	return nil
}

// download gets url, and stores it as filePath, retrying a few more times if the downloads fail.
func (h *Hook) download(url, filePath string, stager *libbuildpack.Stager, creds *credentials) error {
	client := &http.Client{}
	req, _ := http.NewRequest("GET", url, nil)
	if creds.CustomOneAgentURL == "" {
		ver, err := stager.BuildpackVersion()
			if err != nil {
				h.Log.Warning("Failed to get buildpack version: %v", err)
				ver = "unknown"
			}
		req.Header.Set("User-Agent", fmt.Sprintf("cf-%s-buildpack/%s", stager.BuildpackLanguage(), ver))
		req.Header.Set("Authorization", fmt.Sprintf("Api-Token %s", creds.APIToken))
	}

	out, err := os.Create(filePath)
	if err != nil {
		return err
	}
	defer out.Close()
	
	const baseWaitTime = 3 * time.Second
	for i := 0; ; i++ {
		resp, err := client.Do(req)
		if err == nil {
			// We truncate the file to make it empty, we also need to move the offset to the beginning. For errors
			// here, these would be unexpected so we just fail the function without retrying.

			if err = out.Truncate(0); err != nil {
				resp.Body.Close()
				return err
			}

			if _, err = out.Seek(0, io.SeekStart); err != nil {
				resp.Body.Close()
				return err
			}

			// Now we copy the response content into the file.
			_, err = io.Copy(out, resp.Body)

			resp.Body.Close() // Ignore error, nothing worth doing if it fails.

			if resp.StatusCode < 400 && err == nil {
				return nil
			}

			h.Log.Debug("Download returned with status %s, error: %v", resp.Status, err)

			if i == h.MaxDownloadRetries {
				h.Log.Warning("Maximum number of retries attempted: %d", h.MaxDownloadRetries)
				return fmt.Errorf("download returned with status %s, error: %v", resp.Status, err)
			}
		} else {
			h.Log.Debug("Download failed: %v", err)

			if i == h.MaxDownloadRetries {
				h.Log.Warning("Maximum number of retries attempted: %d", h.MaxDownloadRetries)
				return err
			}
		}

		waitTime := baseWaitTime + time.Duration(math.Pow(2, float64(i)))*time.Second
		h.Log.Warning("Error during installer download, retrying in %v", waitTime)
		time.Sleep(waitTime)
	}

}

func (h *Hook) getDownloadURL(c *credentials) string {
	var osType, installerType string
	if runtime.GOOS == "linux" {
		osType = "unix"
		installerType = "paas-sh"
	} else if runtime.GOOS == "windows" {
		osType = "windows"
		installerType = "paas"
	}

	if c.CustomOneAgentURL != "" {
		return c.CustomOneAgentURL
	}

	apiURL, err := h.ensureApiURL(c)
	if err != nil {
		return ""
	}

	u, err := url.ParseRequestURI(fmt.Sprintf("%s/v1/deployment/installer/agent/%s/%s/latest", apiURL, osType, installerType))
	if err != nil {
		return ""
	}

	qv := make(url.Values)
	qv.Add("bitness", "64")
	// only set the networkzone property when it is configured
	if c.NetworkZone != "" {
		qv.Add("networkZone", c.NetworkZone)
	}
	for _, t := range h.IncludeTechnologies {
		qv.Add("include", t)
	}
	if c.AddTechnologies != "" {
		// add optionally configured OneAgent code modules
		for _, t := range strings.Split(c.AddTechnologies, ",") {
			h.Log.Debug("Adding additional code module to download: %s", t)
			qv.Add("include", t)
		}
	}
	u.RawQuery = qv.Encode() // Parameters will be sorted by key.

	return u.String()
}

// ensureApiURL makes sure that a valid URL was provided via the cf service.
// If the c.APIURL property is empty, we assume this is a PaaS setting and generate
// a proper API URL for a PaaS tenant.
func (h *Hook) ensureApiURL(creds *credentials) (string, error) {
	apiURL := creds.APIURL
	if apiURL == "" {
		apiURL = fmt.Sprintf("https://%s.live.dynatrace.com/api", creds.EnvironmentID)
		h.Log.Debug("No apiurl configured, assuming PaaS tenant and setting apiurl to %s", apiURL)
	} else {
		h.Log.Debug("apiurl parameter configured is set to %s, no need to apply PaaS fallback", apiURL)
	}

	url, err := url.ParseRequestURI(apiURL)
	if err != nil {
		h.Log.Error("Failed to verify the configured API URL: %s", err)
		return "", err
	}

	return url.String(), nil
}

// findAgentPath reads the manifest file included in the OneAgent package, and looks
// for the process agent file path.
func (h *Hook) findAgentPath(installDir string, technology string, binaryType string, libraryFilename string, platformName string) (string, error) {
	// With these classes, we try to replicate the structure for the manifest.json file, so that we can parse it.

	type Binary struct {
		Path       string `json:"path"`
		BinaryType string `json:"binarytype"`
	}

	type Architecture map[string][]Binary
	type Technologies map[string]Architecture

	type Manifest struct {
		Technologies Technologies `json:"technologies"`
	}

	fallbackPath := filepath.Join("agent", "lib64", libraryFilename)

	manifestPath := filepath.Join(installDir, "manifest.json")
	if _, err := os.Stat(manifestPath); os.IsNotExist(err) {
		h.Log.Info("manifest.json not found, using fallback!")
		return fallbackPath, nil
	}

	var manifest Manifest

	if raw, err := os.ReadFile(manifestPath); err != nil {
		return "", err
	} else if err = json.Unmarshal(raw, &manifest); err != nil {
		return "", err
	}

	for _, binary := range manifest.Technologies[technology][platformName] {
		if binary.BinaryType == binaryType {
			return binary.Path, nil
		}
	}

	// Using fallback path if we don't find the 'primary' process agent.
	h.Log.Warning("Agent path not found in manifest.json, using fallback!")
	return fallbackPath, nil
}

// Downloads most recent agent config from configuration API of the tenant
// and merges it with the local version the standalone installer package brings along.
func (h *Hook) updateAgentConfig(creds *credentials, installDir string, stager *libbuildpack.Stager) error {
	// agentConfigProperty represents a line of raw data we get from the config api
	type agentConfigProperty struct {
		Section string
		Key     string
		Value   string
	}

	// Container type for agentConfigProperty.
	// Used for easy unmarshalling.
	type properties struct {
		Properties []agentConfigProperty
	}

	// Fetch most recent OneAgent config from API, which we get back in JSON format
	// According to the API spec it always returns at least some sort of Header Info.
	// So, we do not need to handle the case that the request succeeds and the content is empty.
	client := &http.Client{Timeout: 3 * time.Second}
	apiURL, err := h.ensureApiURL(creds)
	if err != nil {
		return err
	}
	agentConfigUrl := apiURL + "/v1/deployment/installer/agent/processmoduleconfig"

	lang := stager.BuildpackLanguage()
	ver, err := stager.BuildpackVersion()
	if err != nil {
		h.Log.Warning("Failed to get buildpack version: %v", err)
		ver = "unknown"
	}

	h.Log.Debug("Downloading updated OneAgent config from %s", agentConfigUrl)
	req, _ := http.NewRequest("GET", agentConfigUrl, nil)
	req.Header.Set("User-Agent", fmt.Sprintf("cf-%s-buildpack/%s", lang, ver))
	req.Header.Set("Authorization", fmt.Sprintf("Api-Token %s", creds.APIToken))
	client.Do(req)
	resp, err := client.Do(req)

	configComment := ""
	configFromAPI := make(map[string]map[string]string)
	if err != nil || resp.StatusCode != 200 {
		h.Log.Warning("Failed to fetch updated OneAgent config from the API")
		configComment = "# Warning: Failed to fetch updated OneAgent config from the API. This config only includes settings provided by the installer.\n"
	} else {
		h.Log.Debug("Successfully fetched updated OneAgent config from the API")
		configComment = "# This config is a merge between the installer and the Cluster config\n"
		var jsonConfig properties
		json.NewDecoder(resp.Body).Decode(&jsonConfig)

		for _, v := range jsonConfig.Properties {
			// you gotta check if the required map is already there
			// if not: initialize it with a nice make :-)
			_, ok := configFromAPI[v.Section]
			if !ok {
				configFromAPI[v.Section] = make(map[string]string)
			}
			configFromAPI[v.Section][v.Key] = v.Value
		}
	}

	// read data from ruxitagentproc.conf file
	agentConfigPath := filepath.Join(installDir, "agent", "conf", "ruxitagentproc.conf")
	agentConfigFile, err := os.Open(agentConfigPath)
	if err != nil {
		h.Log.Error("Failure while reading OneAgent config file %s: %s", agentConfigPath, err)
		return err
	}
	h.Log.Debug("Successfully read OneAgent config from %s", agentConfigPath)
	defer agentConfigFile.Close()

	configFromAgent := make(map[string]map[string]string)
	currentSection := ""
	var configSection string
	var sectionRegexp, _ = regexp.Compile(`\[(.*)\]`)
	configScanner := bufio.NewScanner(agentConfigFile)

	h.Log.Debug("Starting to parse OneAgent config...")
	for configScanner.Scan() {
		// This parses the data we retrieved from ruxitagentproc.conf and stores
		// it into the configFromAgent map of maps that was created above, for easy
		// merging with configFromAPI later on.
		currentLine := configScanner.Text()

		// Check if current line is a section header
		if sectionHeader := sectionRegexp.FindStringSubmatch(currentLine); len(sectionHeader) != 0 {
			configSection = sectionHeader[1]
		} else {
			configSection = ""
		}

		if configSection != "" {
			currentSection = configSection
		} else if strings.HasPrefix(currentLine, "#") { //it's a comment line
			// skipping over lines that are purely comments
			continue
		} else if currentLine == "" {
			// skipping over empty lines
			continue
		} else {
			// you gotta check if the required map is already there
			// if not: initialize it with a nice make :-)
			_, ok := configFromAgent[currentSection]
			if !ok {
				configFromAgent[currentSection] = make(map[string]string)
			}
			configLineKey := strings.Fields(currentLine)[0]
			configLineValue := strings.Join(strings.Fields(currentLine)[1:], " ")
			configFromAgent[currentSection][configLineKey] = configLineValue
		}
	}
	h.Log.Debug("Successfully parsed OneAgent config...")

	// Merge the two configs to get an updated version.
	// Just writes all of configFromAPI over eventually existing values in
	// configFromAgent, since the ones from the API are supposed to be the recent ones.
	// This includes adding possibly new sections and/or property keys.
	h.Log.Debug("Starting with OneAgent configuration merging...")
	for section := range configFromAPI {
		for property := range configFromAPI[section] {
			_, ok := configFromAgent[section]
			if !ok {
				configFromAgent[section] = make(map[string]string)
			}
			configFromAgent[section][property] = configFromAPI[section][property]
		}
	}
	h.Log.Debug("Finished OneAgent configuration merging")

	// open ruxitagentproc.conf to overwrite its content
	overwriteAgentConfigFile, err := os.Create(agentConfigPath)
	if err != nil {
		h.Log.Error("Error opening OneAgent config file %s: %s", agentConfigPath, err)
		return err
	}
	h.Log.Debug("Successfully opened OneAgent config file %s for writing", agentConfigPath)
	defer overwriteAgentConfigFile.Close()

	// Write additional comments to the config
	fmt.Fprintf(overwriteAgentConfigFile, configComment)

	// write merged data to ruxitagentproc.conf
	for section := range configFromAgent {
		fmt.Fprintf(overwriteAgentConfigFile, "[%s]\n", section)
		for k, v := range configFromAgent[section] {
			fmt.Fprintf(overwriteAgentConfigFile, "%s %s\n", k, v)
		}

		// Trailing empty newline at the end of each section for better human readability
		fmt.Fprintf(overwriteAgentConfigFile, "\n")
	}

	h.Log.Debug("Finished writing updated OneAgent config back to %s", agentConfigPath)

	return nil
}
