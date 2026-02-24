package main

import (
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/cloudfoundry/java-buildpack/src/java/supply"
	"github.com/cloudfoundry/libbuildpack"
)

func main() {
	logfile, err := os.CreateTemp("", "cloudfoundry.java-buildpack.supply")
	if err != nil {
		logger := libbuildpack.NewLogger(os.Stdout)
		logger.Error("Unable to create log file: %s", err.Error())
		os.Exit(8)
	}
	defer logfile.Close()

	stdout := io.MultiWriter(os.Stdout, logfile)
	logger := libbuildpack.NewLogger(stdout)

	buildpackDir, err := libbuildpack.GetBuildpackDir()
	if err != nil {
		logger.Error("Unable to determine buildpack directory: %s", err.Error())
		os.Exit(9)
	}

	manifest, err := libbuildpack.NewManifest(buildpackDir, logger, time.Now())
	if err != nil {
		logger.Error("Unable to load buildpack manifest: %s", err.Error())
		os.Exit(10)
	}

	installer := libbuildpack.NewInstaller(manifest)
	stager := libbuildpack.NewStager(os.Args[1:], logger, manifest)

	if err := stager.CheckBuildpackValid(); err != nil {
		os.Exit(11)
	}

	if err = installer.SetAppCacheDir(stager.CacheDir()); err != nil {
		logger.Error("Unable to setup appcache: %s", err)
		os.Exit(18)
	}

	if err = manifest.ApplyOverride(stager.DepsDir()); err != nil {
		logger.Error("Unable to apply override.yml files: %s", err)
		os.Exit(17)
	}

	if err := libbuildpack.RunBeforeCompile(stager); err != nil {
		logger.Error("Before Compile: %s", err.Error())
		os.Exit(12)
	}

	// Create standard directories
	for _, dir := range []string{"bin", "lib", "include", "pkgconfig"} {
		if err := os.MkdirAll(filepath.Join(stager.DepDir(), dir), 0755); err != nil {
			logger.Error("Could not create directory: %s", err.Error())
			os.Exit(12)
		}
	}

	if err := stager.SetStagingEnvironment(); err != nil {
		logger.Error("Unable to setup environment variables: %s", err.Error())
		os.Exit(13)
	}

	s := supply.Supplier{
		Stager:    stager,
		Manifest:  manifest,
		Installer: installer,
		Log:       logger,
		Command:   &libbuildpack.Command{},
	}

	if err = supply.Run(&s); err != nil {
		os.Exit(14)
	}

	if err = installer.CleanupAppCache(); err != nil {
		logger.Error("Unable to clean up app cache: %s", err)
		os.Exit(19)
	}
}
