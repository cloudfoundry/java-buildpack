package finalize

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/java-buildpack/src/java/containers"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/java-buildpack/src/java/jres"
	"github.com/cloudfoundry/libbuildpack"
)

type Finalizer struct {
	Stager    *libbuildpack.Stager
	Manifest  *libbuildpack.Manifest
	Installer *libbuildpack.Installer
	Log       *libbuildpack.Logger
	Command   *libbuildpack.Command
	Container containers.Container
}

// Run performs the finalize phase
func Run(f *Finalizer) error {
	f.Log.BeginStep("Finalizing Java")

	// Create container context
	ctx := &containers.Context{
		Stager:    f.Stager,
		Manifest:  f.Manifest,
		Installer: f.Installer,
		Log:       f.Log,
		Command:   f.Command,
	}

	// Create and populate container registry with standard containers
	registry := containers.NewRegistry(ctx)
	registry.RegisterStandardContainers()

	// Detect which container was used (should match supply phase)
	container, containerName, err := registry.Detect()
	if err != nil {
		f.Log.Error("Failed to detect container: %s", err.Error())
		return err
	}
	if container == nil {
		f.Log.Error("No suitable container found for this application")
		return fmt.Errorf("no suitable container found")
	}

	f.Log.Info("Finalizing container: %s", containerName)
	f.Container = container

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

// finalizeJRE finalizes the JRE configuration (memory calculator, jvmkill, etc.)
func (f *Finalizer) finalizeJRE() error {
	f.Log.BeginStep("Finalizing JRE")

	// Create JRE context
	ctx := &jres.Context{
		Stager:    f.Stager,
		Manifest:  f.Manifest,
		Installer: f.Installer,
		Log:       f.Log,
		Command:   f.Command,
	}

	// Create and populate JRE registry
	// This MUST match the behavior in the supply phase to ensure consistent detection.
	// The finalize phase re-detects the JRE (rather than reading stored config) to support:
	// 1. Multi-buildpack scenarios where supply and finalize may run in different contexts
	// 2. Environment variable overrides that occur between phases
	// 3. Detection of JREs installed by other buildpacks
	registry := jres.NewRegistry(ctx)
	registry.RegisterStandardJREs()

	// Detect which JRE was installed (should match supply phase)
	// With SetDefault(openJDK) configured, this will always return a JRE unless
	// an explicitly configured JRE fails detection
	jre, jreName, err := registry.Detect()
	if err != nil {
		f.Log.Error("Failed to detect JRE: %s", err.Error())
		return err
	}

	f.Log.Info("Finalizing JRE: %s", jreName)

	// Call JRE finalize (this will finalize memory calculator, jvmkill, etc.)
	if err := jre.Finalize(); err != nil {
		f.Log.Warning("Failed to finalize JRE: %s (continuing)", err.Error())
		// Don't fail the build if JRE finalization fails
		return nil
	}

	f.Log.Info("JRE finalization complete")
	return nil
}

// finalizeFrameworks finalizes framework components (APM agents, etc.)
func (f *Finalizer) finalizeFrameworks() error {
	f.Log.BeginStep("Finalizing frameworks")

	// Create framework context
	ctx := &frameworks.Context{
		Stager:    f.Stager,
		Manifest:  f.Manifest,
		Installer: f.Installer,
		Log:       f.Log,
		Command:   f.Command,
	}

	// Create and populate framework registry
	registry := frameworks.NewRegistry(ctx)
	registry.RegisterStandardFrameworks()

	// Detect all frameworks that were installed
	detectedFrameworks, frameworkNames, err := registry.DetectAll()
	if err != nil {
		f.Log.Warning("Failed to detect frameworks: %s", err.Error())
		return nil // Don't fail the build if framework detection fails
	}

	if len(detectedFrameworks) == 0 {
		f.Log.Info("No frameworks to finalize")
		return nil
	}

	f.Log.Info("Finalizing frameworks: %v", frameworkNames)

	// Finalize all detected frameworks
	for i, framework := range detectedFrameworks {
		f.Log.Info("Finalizing framework: %s", frameworkNames[i])
		if err := framework.Finalize(); err != nil {
			f.Log.Warning("Failed to finalize framework %s: %s", frameworkNames[i], err.Error())
			// Continue with other frameworks even if one fails
			continue
		}
	}

	// After all frameworks have written their .opts files, create the centralized assembly script
	// This script reads all .opts files in priority order and assembles JAVA_OPTS at runtime
	if err := frameworks.CreateJavaOptsAssemblyScript(ctx); err != nil {
		f.Log.Warning("Failed to create JAVA_OPTS assembly script: %s", err.Error())
		// Don't fail the build, but this means JAVA_OPTS won't be assembled
	}

	return nil
}

// writeReleaseYaml writes the release configuration to a YAML file
// This follows the pattern used by Ruby, Go, and Node.js buildpacks
func (f *Finalizer) writeReleaseYaml(container containers.Container) error {
	f.Log.BeginStep("Writing release configuration")

	// Get the container's startup command
	containerCommand, err := container.Release()
	if err != nil {
		return fmt.Errorf("failed to get container command: %w", err)
	}

	// Create tmp directory in build dir
	tmpDir := filepath.Join(f.Stager.BuildDir(), "tmp")
	if err := os.MkdirAll(tmpDir, 0755); err != nil {
		return fmt.Errorf("failed to create tmp directory: %w", err)
	}

	// Write YAML file with release information
	releaseYamlPath := filepath.Join(tmpDir, "java-buildpack-release-step.yml")
	yamlContent := fmt.Sprintf(`---
default_process_types:
  web: %s
`, containerCommand)

	if err := os.WriteFile(releaseYamlPath, []byte(yamlContent), 0644); err != nil {
		return fmt.Errorf("failed to write release YAML: %w", err)
	}

	f.Log.Info("Release YAML written: %s", releaseYamlPath)
	f.Log.Info("Web process command: %s", containerCommand)
	return nil
}
