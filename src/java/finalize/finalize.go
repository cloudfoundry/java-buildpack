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
	registry := jres.NewRegistry(ctx)

	// Register the same JRE providers as in supply phase
	// We need to detect which one was used during supply
	registry.Register(jres.NewOpenJDKJRE(ctx))
	registry.Register(jres.NewZuluJRE(ctx))
	registry.Register(jres.NewSapMachineJRE(ctx))
	registry.Register(jres.NewGraalVMJRE(ctx))
	registry.Register(jres.NewIBMJRE(ctx))
	registry.Register(jres.NewOracleJRE(ctx))
	registry.Register(jres.NewZingJRE(ctx))

	// Detect which JRE was installed (should match supply phase)
	jre, jreName, err := registry.Detect()
	if err != nil {
		f.Log.Error("Failed to detect JRE: %s", err.Error())
		return err
	}
	if jre == nil {
		f.Log.Warning("No JRE found during finalize, skipping JRE finalization")
		return nil
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

	// APM Agents (Priority 1)
	registry.Register(frameworks.NewNewRelicFramework(ctx))
	registry.Register(frameworks.NewAppDynamicsFramework(ctx))
	registry.Register(frameworks.NewDynatraceFramework(ctx))
	registry.Register(frameworks.NewDatadogJavaagentFramework(ctx))
	registry.Register(frameworks.NewElasticApmAgentFramework(ctx))

	// Spring Service Bindings (Priority 1)
	registry.Register(frameworks.NewSpringAutoReconfigurationFramework(ctx))
	registry.Register(frameworks.NewJavaCfEnvFramework(ctx))

	// JDBC Drivers (Priority 1)
	registry.Register(frameworks.NewPostgresqlJdbcFramework(ctx))
	registry.Register(frameworks.NewMariaDBJDBCFramework(ctx))

	// mTLS Support (Priority 1)
	registry.Register(frameworks.NewClientCertificateMapperFramework(ctx))

	// Security Providers (Priority 1)
	registry.Register(frameworks.NewContainerSecurityProviderFramework(ctx))
	registry.Register(frameworks.NewLunaSecurityProviderFramework(ctx))

	// Development Tools (Priority 1)
	registry.Register(frameworks.NewDebugFramework(ctx))
	registry.Register(frameworks.NewJmxFramework(ctx))
	registry.Register(frameworks.NewJavaOptsFramework(ctx))

	// APM Agents (Priority 2)
	registry.Register(frameworks.NewAzureApplicationInsightsAgentFramework(ctx))
	registry.Register(frameworks.NewCheckmarxIASTAgentFramework(ctx))
	registry.Register(frameworks.NewGoogleStackdriverDebuggerFramework(ctx))
	registry.Register(frameworks.NewGoogleStackdriverProfilerFramework(ctx))
	registry.Register(frameworks.NewIntroscopeAgentFramework(ctx))
	registry.Register(frameworks.NewOpenTelemetryJavaagentFramework(ctx))
	registry.Register(frameworks.NewRiverbedAppInternalsAgentFramework(ctx))
	registry.Register(frameworks.NewSkyWalkingAgentFramework(ctx))
	registry.Register(frameworks.NewSplunkOtelJavaAgentFramework(ctx))

	// Testing & Code Coverage (Priority 3)
	registry.Register(frameworks.NewJacocoAgentFramework(ctx))

	// Code Instrumentation (Priority 3)
	registry.Register(frameworks.NewJRebelAgentFramework(ctx))
	registry.Register(frameworks.NewContrastSecurityAgentFramework(ctx))
	registry.Register(frameworks.NewAspectJWeaverAgentFramework(ctx))
	registry.Register(frameworks.NewTakipiAgentFramework(ctx))
	registry.Register(frameworks.NewYourKitProfilerFramework(ctx))
	registry.Register(frameworks.NewJProfilerProfilerFramework(ctx))
	registry.Register(frameworks.NewSealightsAgentFramework(ctx))

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
