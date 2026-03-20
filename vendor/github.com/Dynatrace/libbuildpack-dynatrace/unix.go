package dynatrace

import (
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/libbuildpack"
)

func (h *Hook) runInstallerUnix(installerFilePath, installDir string, creds *credentials, stager *libbuildpack.Stager) error {
	h.Log.Debug("Making %s executable...", installerFilePath)
	err := os.Chmod(installerFilePath, 0755)
	if err != nil {
		h.Log.Error("Error while setting installer file %s executable", installerFilePath)
		return err
	}


	h.Log.BeginStep("Starting Dynatrace OneAgent installer")

	if os.Getenv("BP_DEBUG") != "" {
		err = h.Command.Execute("", os.Stdout, os.Stderr, installerFilePath, stager.BuildDir())
	} else {
		err = h.Command.Execute("", io.Discard, io.Discard, installerFilePath, stager.BuildDir())
	}
	if err != nil {
		return err
	}

	h.Log.Info("Dynatrace OneAgent installed.")

	// Post-installation setup...

	dynatraceEnvName := "dynatrace-env.sh"
	dynatraceEnvPath := filepath.Join(stager.DepDir(), "profile.d", dynatraceEnvName)
	agentLibPath, err := h.findAgentPath(filepath.Join(stager.BuildDir(), installDir), "process", "primary", "liboneagentproc.so", "linux-x86-64")
	if err != nil {
		h.Log.Error("Manifest handling failed!")
		return err
	}

	agentLibPath = filepath.Join(installDir, agentLibPath)
	agentBuilderLibPath := filepath.Join(stager.BuildDir(), agentLibPath)

	if _, err = os.Stat(agentBuilderLibPath); os.IsNotExist(err) {
		h.Log.Error("Agent library (%s) not found!", agentBuilderLibPath)
		return err
	}

	h.Log.BeginStep("Setting up Dynatrace OneAgent injection...")
	h.Log.Debug("Copy %s to %s", dynatraceEnvName, dynatraceEnvPath)
	if err = libbuildpack.CopyFile(filepath.Join(stager.BuildDir(), installDir, dynatraceEnvName), dynatraceEnvPath); err != nil {
		return err
	}

	h.Log.Debug("Open %s for modification...", dynatraceEnvPath)
	f, err := os.OpenFile(dynatraceEnvPath, os.O_APPEND|os.O_WRONLY, os.ModeAppend)
	if err != nil {
		return err
	}

	defer f.Close()

	extra := ""

	h.Log.Debug("Setting LD_PRELOAD...")
	extra += fmt.Sprintf("\nexport LD_PRELOAD=${HOME}/%s", agentLibPath)

	if creds.NetworkZone != "" {
		h.Log.Debug("Setting DT_NETWORK_ZONE...")
		extra += fmt.Sprintf("\nexport DT_NETWORK_ZONE=${DT_NETWORK_ZONE:-%s}", creds.NetworkZone)
	}

	// By default, OneAgent logs are printed to stderr. If the customer doesn't override this behavior through an
	// environment variable, then we change the default output to stdout.
	if os.Getenv("DT_LOGSTREAM") == "" {
		h.Log.Debug("Setting DT_LOGSTREAM to stdout...")
		extra += "\nexport DT_LOGSTREAM=stdout"
	}

	ver, err := stager.BuildpackVersion()
	if err != nil {
		h.Log.Warning("Failed to get buildpack version: %v", err)
		ver = "unknown"
	}
	h.Log.Debug("Preparing custom properties...")
	extra += fmt.Sprintf(
		"\nexport DT_CUSTOM_PROP=\"${DT_CUSTOM_PROP} CloudFoundryBuildpackLanguage=%s CloudFoundryBuildpackVersion=%s\"", stager.BuildpackLanguage(), ver)

	if _, err = f.WriteString(extra); err != nil {
		return err
	}

	return nil
}
