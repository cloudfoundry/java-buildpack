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

type CfMetricsExporterFramework struct {
	context *common.Context
	jarPath string
}

func NewCfMetricsExporterFramework(ctx *common.Context) *CfMetricsExporterFramework {
	return &CfMetricsExporterFramework{context: ctx}
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

	// Ensure agent directory exists
	if err := os.MkdirAll(agentDir, 0755); err != nil {
		return fmt.Errorf("failed to create agent dir: %w", err)
	}

	// Download the JAR if not present
	if _, err := os.Stat(f.jarPath); os.IsNotExist(err) {
		if err := f.context.Installer.InstallDependency(dep, agentDir); err != nil {
			return fmt.Errorf("failed to download cf-metrics-exporter: %w", err)
		}
		err := f.constructJarPath(agentDir)
		if err != nil {
			return fmt.Errorf("cf metrics exporter agent not found during supply: %w", err)
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

	agentDir := filepath.Join(f.context.Stager.DepDir(), cfMetricsExporterDirName)

	err := f.constructJarPath(agentDir)
	if err != nil {
		return fmt.Errorf("cf metrics exporter agent jar path not found during finalize: %w", err)
	}

	relPath, err := filepath.Rel(f.context.Stager.DepDir(), f.jarPath)
	if err != nil {
		return fmt.Errorf("failed to determine relative path for cf metrics exporter agent: %w", err)
	}

	depsIdx := f.context.Stager.DepsIdx()
	agentPath := filepath.Join(fmt.Sprintf("$DEPS_DIR/%s", depsIdx), relPath)

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

func (f *CfMetricsExporterFramework) constructJarPath(agentDir string) error {
	// Find the installed JAR
	jarPattern := filepath.Join(agentDir, "cf-metrics-exporter*.jar")
	matches, err := filepath.Glob(jarPattern)
	if err != nil {
		return fmt.Errorf("failed to search for CF Metrics Exported jar: %w", err)
	}
	if len(matches) == 0 {
		return fmt.Errorf("agent jar not found after installation in %s", agentDir)
	}
	f.jarPath = matches[0]
	return nil
}
