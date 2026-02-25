package frameworks

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/libbuildpack"
)

const cfMetricsExporterDependencyName = "cf-metrics-exporter"
const cfMetricsExporterDirName = "cf_metrics_exporter"

// Installer interface for dependency installation
// Allows for mocking in tests
// Only the InstallDependency method is needed for this framework
// (matches the signature of libbuildpack.Installer)
type Installer interface {
	InstallDependency(dep libbuildpack.Dependency, outputDir string) error
}

type CfMetricsExporterFramework struct {
	context   *common.Context
	installer Installer
}

func NewCfMetricsExporterFramework(ctx *common.Context) *CfMetricsExporterFramework {
	installer := ctx.Installer
	return &CfMetricsExporterFramework{context: ctx, installer: installer}
}

func (f *CfMetricsExporterFramework) Detect() (string, error) {
	enabled := os.Getenv("CF_METRICS_EXPORTER_ENABLED")
	if enabled == "true" || enabled == "TRUE" {
		_, err := f.context.Manifest.DefaultVersion(cfMetricsExporterDependencyName)
		if err != nil {
			return "", fmt.Errorf("cf-metrics-exporter version not found in manifest: %w", err)
		}
		return "CF Metrics Exporter", nil
	}
	return "", nil
}

func (f *CfMetricsExporterFramework) getManifestDependency() (libbuildpack.Dependency, *libbuildpack.ManifestEntry, error) {
	dep, err := f.context.Manifest.DefaultVersion(cfMetricsExporterDependencyName)
	if err != nil {
		return libbuildpack.Dependency{}, nil, fmt.Errorf("cf-metrics-exporter version not found in manifest: %w", err)
	}
	entry, err := f.context.Manifest.GetEntry(dep)
	if err != nil {
		return dep, nil, fmt.Errorf("cf-metrics-exporter manifest entry not found: %w", err)
	}
	return dep, entry, nil
}

func (f *CfMetricsExporterFramework) Supply() error {
	enabled := os.Getenv("CF_METRICS_EXPORTER_ENABLED")
	if enabled != "true" && enabled != "TRUE" {
		return nil
	}

	dep, _, err := f.getManifestDependency()
	if err != nil {
		return err
	}

	agentDir := filepath.Join(f.context.Stager.DepDir(), cfMetricsExporterDirName)
	jarName := fmt.Sprintf("cf-metrics-exporter-%s.jar", dep.Version)
	jarPath := filepath.Join(agentDir, jarName)

	// Ensure agent directory exists
	if err := os.MkdirAll(agentDir, 0755); err != nil {
		return fmt.Errorf("failed to create agent dir: %w", err)
	}

	// Download the JAR if not present
	if _, err := os.Stat(jarPath); os.IsNotExist(err) {
		if err := f.installer.InstallDependency(dep, agentDir); err != nil {
			return fmt.Errorf("failed to download cf-metrics-exporter: %w", err)
		}
		if _, err := os.Stat(jarPath); err != nil {
			return fmt.Errorf("expected jar file not found after download: %w", err)
		}
	}

	// Log activation, including properties if set
	props := os.Getenv("CF_METRICS_EXPORTER_PROPS")
	if props != "" {
		f.context.Log.Info("CF Metrics Exporter v%s enabled, with properties: %s", dep.Version, props)
	} else {
		f.context.Log.Info("CF Metrics Exporter v%s enabled", dep.Version)
	}

	return nil
}

func (f *CfMetricsExporterFramework) Finalize() error {
	enabled := os.Getenv("CF_METRICS_EXPORTER_ENABLED")
	if enabled != "true" && enabled != "TRUE" {
		return nil
	}

	dep, _, err := f.getManifestDependency()
	if err != nil {
		return err
	}

	jarName := fmt.Sprintf("cf-metrics-exporter-%s.jar", dep.Version)
	depsIdx := f.context.Stager.DepsIdx()
	agentPath := fmt.Sprintf("$DEPS_DIR/%s/cf_metrics_exporter/%s", depsIdx, jarName)

	props := os.Getenv("CF_METRICS_EXPORTER_PROPS")
	var javaOpt string
	if props != "" {
		javaOpt = fmt.Sprintf("-javaagent:%s=%s", agentPath, props)
	} else {
		javaOpt = fmt.Sprintf("-javaagent:%s", agentPath)
	}

	// Priority 43: after SkyWalking (41), Splunk OTEL (42)
	return writeJavaOptsFile(f.context, 43, cfMetricsExporterDirName, javaOpt)
}
