package dynatrace

import (
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/cloudfoundry/libbuildpack"
)

func (h *Hook) runInstallerWindows(installerFilePath, installDir string, creds *credentials, stager *libbuildpack.Stager) error {
	h.Log.BeginStep("Starting Dynatrace OneAgent installation")

	h.Log.Info("Unzipping archive '%s' to '%s'", installerFilePath, filepath.Join(stager.BuildDir(), installDir))
	err := libbuildpack.ExtractZip(installerFilePath, filepath.Join(stager.BuildDir(), installDir))
	if err != nil {
		h.Log.Error("Error during unzipping paas archive")
		return err
	}

	h.Log.Info("Dynatrace OneAgent installed.")

	// Post-installation setup...

	h.Log.BeginStep("Setting up Dynatrace OneAgent injection...")
	if slices.Contains(h.IncludeTechnologies, "dotnet") {
		err = h.setUpDotNetCorProfilerInjection(creds, installDir, stager)
	} else {
		h.Log.Warning("No injection method available for technology stack")
		return nil
	}
	if err != nil {
		return err
	}

	return nil
}

func (h *Hook) setUpDotNetCorProfilerInjection(creds *credentials, installDir string, stager *libbuildpack.Stager) error {
	loaderPath, err := h.findAbsoluteLoaderPath(stager, installDir)
	if err != nil {
		return fmt.Errorf("cannot find oneagentloader.dll: %s", err)
	}

	scriptContent := "set COR_ENABLE_PROFILING=1\n"
	scriptContent += "set COR_PROFILER={B7038F67-52FC-4DA2-AB02-969B3C1EDA03}\n"
	scriptContent += "set DT_AGENTACTIVE=true\n"
	scriptContent += "set DT_BLOCKLIST=powershell*\n"
	scriptContent += fmt.Sprintf("set COR_PROFILER_PATH_64=%s\n", loaderPath)

	if creds.NetworkZone != "" {
		h.Log.Debug("Setting DT_NETWORK_ZONE...")
		scriptContent += "set DT_NETWORK_ZONE=" + creds.NetworkZone + "\n"
	}

	ver, err := stager.BuildpackVersion()
	if err != nil {
		h.Log.Warning("Failed to get buildpack version: %v", err)
		ver = "unknown"
	}
	h.Log.Debug("Preparing custom properties...")
	scriptContent += fmt.Sprintf("set DT_CUSTOM_PROP=\"%%DT_CUSTOM_PROP%% CloudFoundryBuildpackLanguage=%s CloudFoundryBuildpackVersion=%s\"\n", stager.BuildpackLanguage(), ver)

	stager.WriteProfileD("dynatrace-env.cmd", scriptContent)

	return nil
}

func (h *Hook) findAbsoluteLoaderPath(stager *libbuildpack.Stager, installDir string) (string, error) {

	// look for dotnet loader DLL file relative to the root of the downloaded zip archive
	// and get the path from the manifest e.g. agent/bin/windows-x86-64/oneagentloader.dll
	loaderDllPath, err := h.findAgentPath(filepath.Join(stager.BuildDir(), installDir), "dotnet", "loader", "oneagentloader.dll", "windows-x86-64")
	if err != nil {
		h.Log.Error("Manifest handling failed!")
		return "", err
	}

	// windows path separator is "\" instead of "/"
	loaderDllPath = strings.ReplaceAll(loaderDllPath, "/", "\\")

	// build the loader DLL path relative to the app directory
	// e.g. dynatrace/oneagent/agent/bin/windows-x86-64/oneagentloader.dll
	loaderDllPathInAppDir := filepath.Join(installDir, loaderDllPath)

	// check that the loader dll is present in the build dir
	// e.g. at \tmp\app\dynatrace\oneagent\agent\bin\1.303.0.20240930-081133\windows-x86-32\oneagentloader.dll
	loaderDllPathInBuildDir := filepath.Join(stager.BuildDir(), loaderDllPathInAppDir)

	if _, err = os.Stat(loaderDllPathInBuildDir); os.IsNotExist(err) {
		h.Log.Error("Agent library (%s) not found!", loaderDllPathInBuildDir)
		return "", err
	}

	// build the absolute path of the loader DLL as it will be available at runtime
	return filepath.Join("C:\\users\\vcap\\app", loaderDllPathInAppDir), nil
}
