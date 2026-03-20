package frameworks

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/libbuildpack"
)

// Helper functions for test setup
func setEnvVars(t *testing.T, vars map[string]string) {
	for k, v := range vars {
		if err := os.Setenv(k, v); err != nil {
			t.Fatalf("Setenv %s failed: %v", k, err)
		}
	}
}

func unsetEnvVars(t *testing.T, vars []string) {
	for _, k := range vars {
		if err := os.Unsetenv(k); err != nil {
			t.Fatalf("Unsetenv %s failed: %v", k, err)
		}
	}
}

func loadManifest(t *testing.T) *libbuildpack.Manifest {
	manifestDir := filepath.Join("../../../")
	logger := libbuildpack.NewLogger(os.Stdout)
	manifest, err := libbuildpack.NewManifest(manifestDir, logger, time.Now())
	if err != nil {
		t.Fatalf("Failed to load manifest.yml: %v", err)
	}
	return manifest
}

func TestDetectEnabledWithRealManifest(t *testing.T) {
	setEnvVars(t, map[string]string{
		"CF_METRICS_EXPORTER_ENABLED": "true",
		"CF_STACK":                    "cflinuxfs4",
	})
	defer unsetEnvVars(t, []string{"CF_METRICS_EXPORTER_ENABLED", "CF_STACK"})

	manifest := loadManifest(t)
	ctx := &common.Context{Manifest: manifest}
	ctx.Log = libbuildpack.NewLogger(os.Stdout)
	f := NewCfMetricsExporterFramework(ctx)

	name, err := f.Detect()
	if err != nil {
		t.Fatalf("Detect() error: %v", err)
	}
	if name == "" {
		t.Error("Detect() should return non-empty name when enabled")
	}
}

func TestDetectDisabledWithRealManifest(t *testing.T) {
	setEnvVars(t, map[string]string{"CF_METRICS_EXPORTER_ENABLED": "false"})
	defer unsetEnvVars(t, []string{"CF_METRICS_EXPORTER_ENABLED"})

	manifest := loadManifest(t)
	ctx := &common.Context{Manifest: manifest}
	ctx.Log = libbuildpack.NewLogger(os.Stdout)
	f := NewCfMetricsExporterFramework(ctx)

	name, err := f.Detect()
	if err != nil {
		t.Fatalf("Detect() error: %v", err)
	}
	if name != "" {
		t.Error("Detect() should return empty name when disabled")
	}
}

func TestSupplyPlacesJarCorrectly(t *testing.T) {
	setEnvVars(t, map[string]string{
		"CF_METRICS_EXPORTER_ENABLED": "true",
		"CF_STACK":                    "cflinuxfs4",
	})
	defer unsetEnvVars(t, []string{"CF_METRICS_EXPORTER_ENABLED", "CF_STACK"})

	manifest := loadManifest(t)
	// Setup temp dependency dir
	tmpDepDir, err := os.MkdirTemp("", "cf_metrics_exporter_test")
	if err != nil {
		t.Fatalf("Failed to create temp dep dir: %v", err)
	}
	defer func() {
		_ = os.RemoveAll(tmpDepDir)
	}()

	args := []string{"", "", tmpDepDir, "0"}
	ctx := &common.Context{Manifest: manifest}
	ctx.Stager = libbuildpack.NewStager(args, libbuildpack.NewLogger(os.Stdout), manifest)
	ctx.Log = libbuildpack.NewLogger(os.Stdout)
	ctx.Installer = libbuildpack.NewInstaller(manifest)

	// Pre-create the expected JAR file
	jarName := "cf-metrics-exporter-0.7.1.jar" // adjust if version changes in manifest
	jarDir := filepath.Join(tmpDepDir, "cf_metrics_exporter")
	if err := os.MkdirAll(jarDir, 0755); err != nil {
		t.Fatalf("Failed to create jar dir: %v", err)
	}
	jarPath := filepath.Join(jarDir, jarName)
	fJar, err := os.Create(jarPath)
	if err != nil {
		t.Fatalf("Failed to create jar file: %v", err)
	}
	if err := fJar.Close(); err != nil {
		t.Fatalf("Failed to close jar file: %v", err)
	}

	f := NewCfMetricsExporterFramework(ctx)

	if err := f.Supply(); err != nil {
		t.Fatalf("Supply() error: %v", err)
	}

	// Assert JAR file exists directly in cf_metrics_exporter
	if fi, err := os.Stat(jarPath); err != nil {
		t.Errorf("JAR file not found at expected path: %s, error: %v", jarPath, err)
	} else if fi.IsDir() {
		t.Errorf("Expected file but found directory at: %s", jarPath)
	}
}

func TestSupplyLogsProps(t *testing.T) {
	setEnvVars(t, map[string]string{
		"CF_METRICS_EXPORTER_ENABLED": "true",
		"CF_STACK":                    "cflinuxfs4",
		"CF_METRICS_EXPORTER_PROPS":   "foo=bar,abc=123",
	})
	defer unsetEnvVars(t, []string{"CF_METRICS_EXPORTER_ENABLED", "CF_STACK", "CF_METRICS_EXPORTER_PROPS"})

	manifest := loadManifest(t)
	tmpDepDir, err := os.MkdirTemp("", "cf_metrics_exporter_test_props")
	if err != nil {
		t.Fatalf("Failed to create temp dep dir: %v", err)
	}
	defer func() { _ = os.RemoveAll(tmpDepDir) }()

	args := []string{"", "", tmpDepDir, "0"}
	ctx := &common.Context{Manifest: manifest}
	ctx.Stager = libbuildpack.NewStager(args, libbuildpack.NewLogger(os.Stdout), manifest)
	ctx.Installer = libbuildpack.NewInstaller(manifest)

	// Pre-create the expected JAR file
	jarName := "cf-metrics-exporter-0.7.1.jar"
	jarDir := filepath.Join(tmpDepDir, "cf_metrics_exporter")
	if err := os.MkdirAll(jarDir, 0755); err != nil {
		t.Fatalf("Failed to create jar dir: %v", err)
	}
	jarPath := filepath.Join(jarDir, jarName)
	fJar, err := os.Create(jarPath)
	if err != nil {
		t.Fatalf("Failed to create jar file: %v", err)
	}
	if err := fJar.Close(); err != nil {
		t.Fatalf("Failed to close jar file: %v", err)
	}

	// Capture log output
	logBuf := &logBuffer{}
	ctx.Log = libbuildpack.NewLogger(logBuf)

	f := NewCfMetricsExporterFramework(ctx)
	if err := f.Supply(); err != nil {
		t.Fatalf("Supply() error: %v", err)
	}

	if got := logBuf.String(); !strings.Contains(got, "foo=bar,abc=123") {
		t.Errorf("Expected log to contain CF_METRICS_EXPORTER_PROPS value, got: %s", got)
	}
}

type logBuffer struct {
	buf []byte
}

func (l *logBuffer) Write(p []byte) (n int, err error) {
	l.buf = append(l.buf, p...)
	return len(p), nil
}

func (l *logBuffer) String() string {
	return string(l.buf)
}
