package finalize

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/java-buildpack/src/java/common"

	"github.com/cloudfoundry/java-buildpack/src/java/containers"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/java-buildpack/src/java/jres"
	"github.com/cloudfoundry/libbuildpack"
)

type Finalizer struct {
	Stager        common.Stager
	Manifest      common.Manifest
	Installer     common.Installer
	Log           *libbuildpack.Logger
	Command       common.Command
	Container     containers.Container
	JRE           jres.JRE
	ContainerName string
	JREName       string
}

// SupplyConfig holds the values written to config.yml by the supply phase.
type SupplyConfig struct {
	Container  string `yaml:"container"`
	JRE        string `yaml:"jre"`
	JREVersion string `yaml:"jre_version"`
	JavaHome   string `yaml:"java_home"`
}

// NewFinalizer creates a Finalizer by reading the config.yml written by the supply phase.
// This follows the pattern established by go-buildpack and dotnet-core-buildpack.
func NewFinalizer(stager *libbuildpack.Stager, manifest *libbuildpack.Manifest,
	installer *libbuildpack.Installer, logger *libbuildpack.Logger,
	command *libbuildpack.Command) (*Finalizer, error) {

	raw := struct {
		Config SupplyConfig `yaml:"config"`
	}{}
	if err := libbuildpack.NewYAML().Load(filepath.Join(stager.DepDir(), "config.yml"), &raw); err != nil {
		logger.Error("Unable to read supply phase config.yml: %s", err)
		return nil, err
	}

	cfg := raw.Config
	if cfg.Container == "" || cfg.JRE == "" {
		return nil, fmt.Errorf("config.yml is missing required keys: container=%q jre=%q", cfg.Container, cfg.JRE)
	}

	logger.Info("Loaded supply config: container=%s jre=%s version=%s", cfg.Container, cfg.JRE, cfg.JREVersion)

	return &Finalizer{
		Stager:        stager,
		Manifest:      manifest,
		Installer:     installer,
		Log:           logger,
		Command:       command,
		ContainerName: cfg.Container,
		JREName:       cfg.JRE,
	}, nil
}

// Run performs the finalize phase
func Run(f *Finalizer) error {
	f.Log.BeginStep("Finalizing Java")

	ctx := &common.Context{
		Stager:    f.Stager,
		Manifest:  f.Manifest,
		Installer: f.Installer,
		Log:       f.Log,
		Command:   f.Command,
	}

	// Resolve container using the name stored by supply — no re-detection needed.
	container, err := resolveContainer(ctx, f.ContainerName)
	if err != nil {
		f.Log.Error("Failed to resolve container %q: %s", f.ContainerName, err.Error())
		return err
	}
	f.Container = container

	f.Log.Info("Finalizing container: %s", f.ContainerName)

	// Resolve JRE using the name stored by supply — no re-detection needed.
	jre, err := resolveJRE(ctx, f.JREName)
	if err != nil {
		f.Log.Error("Failed to resolve JRE %q: %s", f.JREName, err.Error())
		return err
	}
	f.JRE = jre

	// Finalize JRE (memory calculator, jvmkill, etc.)
	if err := f.finalizeJRE(); err != nil {
		f.Log.Error("Failed to finalize JRE: %s", err.Error())
		return err
	}

	// Finalize frameworks (APM agents, etc.)
	if err := f.finalizeFrameworks(); err != nil {
		f.Log.Error("Failed to finalize frameworks: %s", err.Error())
		return err
	}

	// Call container's finalize method
	if err := container.Finalize(); err != nil {
		f.Log.Error("Failed to finalize container: %s", err.Error())
		return err
	}

	// Write release YAML configuration
	if err := f.writeReleaseYaml(container); err != nil {
		f.Log.Error("Failed to write release YAML: %s", err.Error())
		return err
	}

	f.Log.Info("Java buildpack finalization complete")
	return nil
}

// resolveContainer finds the container registered under the given name.
func resolveContainer(ctx *common.Context, name string) (containers.Container, error) {
	registry := containers.NewRegistry(ctx)
	registry.RegisterStandardContainers()
	container := registry.Get(name)
	if container == nil {
		return nil, fmt.Errorf("no container registered with name %q", name)
	}
	return container, nil
}

// resolveJRE finds the JRE registered under the given name.
func resolveJRE(ctx *common.Context, name string) (jres.JRE, error) {
	registry := jres.NewRegistry(ctx)
	registry.RegisterStandardJREs()
	jre := registry.Get(name)
	if jre == nil {
		return nil, fmt.Errorf("no JRE registered with name %q", name)
	}
	return jre, nil
}

// finalizeJRE finalizes the JRE configuration (memory calculator, jvmkill, etc.)
func (f *Finalizer) finalizeJRE() error {
	f.Log.BeginStep("Finalizing JRE: %s", f.JREName)

	if err := f.JRE.Finalize(); err != nil {
		f.Log.Warning("Failed to finalize JRE: %s (continuing)", err.Error())
		// Don't fail the build if JRE finalization fails
	}

	f.Log.Info("JRE finalization complete")
	return nil
}

// finalizeFrameworks finalizes framework components (APM agents, etc.)
func (f *Finalizer) finalizeFrameworks() error {
	f.Log.BeginStep("Finalizing frameworks")

	ctx := &common.Context{
		Stager:    f.Stager,
		Manifest:  f.Manifest,
		Installer: f.Installer,
		Log:       f.Log,
		Command:   f.Command,
	}

	registry := frameworks.NewRegistry(ctx)
	registry.RegisterStandardFrameworks()

	detectedFrameworks, frameworkNames, err := registry.DetectAll()
	if err != nil {
		f.Log.Warning("Failed to detect frameworks: %s", err.Error())
		return nil // Don't fail the build if framework detection fails
	}

	if len(detectedFrameworks) == 0 {
		f.Log.Info("No frameworks to finalize")
		return nil
	}

	f.Log.Info("Finalizing frameworks: %v", strings.Join(frameworkNames, ","))

	for i, framework := range detectedFrameworks {
		f.Log.Info("Finalizing framework: %s", frameworkNames[i])
		if err := framework.Finalize(); err != nil {
			f.Log.Warning("Failed to finalize framework %s: %s", frameworkNames[i], err.Error())
			// Continue with other frameworks even if one fails
		}
	}

	// After all frameworks have written their .opts files, create the centralized assembly script
	if err := frameworks.CreateJavaOptsAssemblyScript(ctx); err != nil {
		f.Log.Warning("Failed to create JAVA_OPTS assembly script: %s", err.Error())
	}

	return nil
}

// writeReleaseYaml writes the release configuration to a YAML file
func (f *Finalizer) writeReleaseYaml(container containers.Container) error {
	f.Log.BeginStep("Writing release configuration")

	containerCommand, err := container.Release()
	if err != nil {
		return fmt.Errorf("failed to get container command: %w", err)
	}

	var fullCommand string
	if f.JRE != nil {
		memCalcCmd := f.JRE.MemoryCalculatorCommand()
		if memCalcCmd != "" {
			fullCommand = memCalcCmd + " && " + containerCommand
			f.Log.Debug("Prepended memory calculator command to startup")
		} else {
			fullCommand = containerCommand
		}
	} else {
		fullCommand = containerCommand
	}

	tmpDir := filepath.Join(f.Stager.BuildDir(), "tmp")
	if err := os.MkdirAll(tmpDir, 0755); err != nil {
		return fmt.Errorf("failed to create tmp directory: %w", err)
	}

	releaseYamlPath := filepath.Join(tmpDir, "java-buildpack-release-step.yml")
	yamlContent := fmt.Sprintf(`---
default_process_types:
  web: '%s'
`, fullCommand)

	if err := os.WriteFile(releaseYamlPath, []byte(yamlContent), 0644); err != nil {
		return fmt.Errorf("failed to write release YAML: %w", err)
	}

	f.Log.Info("Release YAML written: %s", releaseYamlPath)
	f.Log.Info("Web process command: %s", fullCommand)
	return nil
}
