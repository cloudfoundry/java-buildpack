package supply

import (
	"fmt"

	"github.com/cloudfoundry/java-buildpack/src/java/containers"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/java-buildpack/src/java/jres"
	"github.com/cloudfoundry/libbuildpack"
)

type Supplier struct {
	Stager    *libbuildpack.Stager
	Manifest  *libbuildpack.Manifest
	Installer *libbuildpack.Installer
	Log       *libbuildpack.Logger
	Command   *libbuildpack.Command
	Container containers.Container
}

// Run performs the supply phase
func Run(s *Supplier) error {
	s.Log.BeginStep("Supplying Java")

	// Create container context
	ctx := &containers.Context{
		Stager:    s.Stager,
		Manifest:  s.Manifest,
		Installer: s.Installer,
		Log:       s.Log,
		Command:   s.Command,
	}

	// Create and populate container registry with standard containers
	registry := containers.NewRegistry(ctx)
	registry.RegisterStandardContainers()

	// Detect which container to use
	container, containerName, err := registry.Detect()
	if err != nil {
		s.Log.Error("Failed to detect container: %s", err.Error())
		return err
	}
	if container == nil {
		s.Log.Error("No suitable container found for this application")
		return fmt.Errorf("no suitable container found")
	}

	s.Log.Info("Detected container: %s", containerName)
	s.Container = container

	// Install JRE
	if err := s.installJRE(); err != nil {
		s.Log.Error("Failed to install JRE: %s", err.Error())
		return err
	}

	// Install frameworks (APM agents, etc.)
	if err := s.installFrameworks(); err != nil {
		s.Log.Error("Failed to install frameworks: %s", err.Error())
		return err
	}

	// Call container's supply method
	if err := container.Supply(); err != nil {
		s.Log.Error("Failed to supply container: %s", err.Error())
		return err
	}

	// Store container name for finalize/release phases
	if err := s.Stager.WriteConfigYml(map[string]string{
		"container": containerName,
	}); err != nil {
		s.Log.Warning("Could not write config: %s", err.Error())
	}

	return nil
}

// installJRE installs the Java Runtime Environment
func (s *Supplier) installJRE() error {
	// Create JRE context
	ctx := &jres.Context{
		Stager:    s.Stager,
		Manifest:  s.Manifest,
		Installer: s.Installer,
		Log:       s.Log,
		Command:   s.Command,
	}

	// Create and populate JRE registry
	registry := jres.NewRegistry(ctx)
	registry.RegisterStandardJREs()

	// Detect which JRE to use
	// With SetDefault(openJDK) configured, this will always return a JRE unless
	// an explicitly configured JRE fails detection
	jre, jreName, err := registry.Detect()
	if err != nil {
		s.Log.Error("Failed to detect JRE: %s", err.Error())
		return err
	}

	s.Log.Info("Selected JRE: %s", jreName)

	// Install the JRE
	if err := jre.Supply(); err != nil {
		s.Log.Error("Failed to install JRE: %s", err.Error())
		return err
	}

	// Store JRE info for finalize/release phases
	if err := s.Stager.WriteConfigYml(map[string]string{
		"jre":         jreName,
		"jre_version": jre.Version(),
		"java_home":   jre.JavaHome(),
	}); err != nil {
		s.Log.Warning("Could not write JRE config: %s", err.Error())
	}

	s.Log.Info("JRE installation complete: %s %s", jreName, jre.Version())
	return nil
}

// installFrameworks installs framework components (APM agents, etc.)
func (s *Supplier) installFrameworks() error {
	s.Log.BeginStep("Installing frameworks")

	// Create framework context
	ctx := &frameworks.Context{
		Stager:    s.Stager,
		Manifest:  s.Manifest,
		Installer: s.Installer,
		Log:       s.Log,
		Command:   s.Command,
	}

	// Create and populate framework registry
	registry := frameworks.NewRegistry(ctx)
	registry.RegisterStandardFrameworks()

	// Detect all frameworks that should be installed
	detectedFrameworks, frameworkNames, err := registry.DetectAll()
	if err != nil {
		s.Log.Warning("Failed to detect frameworks: %s", err.Error())
		return nil // Don't fail the build if framework detection fails
	}

	if len(detectedFrameworks) == 0 {
		s.Log.Info("No frameworks detected")
		return nil
	}

	s.Log.Info("Detected frameworks: %v", frameworkNames)

	// Install all detected frameworks
	for i, framework := range detectedFrameworks {
		s.Log.Info("Installing framework: %s", frameworkNames[i])
		if err := framework.Supply(); err != nil {
			s.Log.Warning("Failed to install framework %s: %s", frameworkNames[i], err.Error())
			// Continue with other frameworks even if one fails
			continue
		}
	}

	return nil
}
