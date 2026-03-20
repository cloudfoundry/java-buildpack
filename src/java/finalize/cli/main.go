package main

import (
	"io"
	"os"
	"time"

	"github.com/cloudfoundry/java-buildpack/src/java/finalize"
	_ "github.com/cloudfoundry/java-buildpack/src/java/hooks" // Register hooks (Dynatrace)
	"github.com/cloudfoundry/libbuildpack"
)

func main() {
	logfile, err := os.CreateTemp("", "cloudfoundry.java-buildpack.finalize")
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

	if err = manifest.ApplyOverride(stager.DepsDir()); err != nil {
		logger.Error("Unable to apply override.yml files: %s", err)
		os.Exit(17)
	}

	if err := stager.SetStagingEnvironment(); err != nil {
		logger.Error("Unable to setup environment variables: %s", err.Error())
		os.Exit(10)
	}

	f, err := finalize.NewFinalizer(stager, manifest, installer, logger, &libbuildpack.Command{})
	if err != nil {
		logger.Error("Unable to initialize finalizer from supply config: %s", err.Error())
		os.Exit(11)
	}

	if err = finalize.Run(f); err != nil {
		os.Exit(12)
	}

	if err := libbuildpack.RunAfterCompile(stager); err != nil {
		logger.Error("After Compile: %s", err.Error())
		os.Exit(13)
	}

	if err := stager.SetLaunchEnvironment(); err != nil {
		logger.Error("Unable to setup launch environment: %s", err.Error())
		os.Exit(14)
	}

	stager.StagingComplete()
}
