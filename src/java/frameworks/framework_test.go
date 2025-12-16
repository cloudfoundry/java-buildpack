package frameworks_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/libbuildpack"
)

// Note: This file contains basic unit tests for the framework system.
// To run these tests, you need to install Ginkgo and Gomega:
//   go get github.com/onsi/ginkgo
//   go get github.com/onsi/gomega

// TestVCAPServicesHasService tests the HasService method
func TestVCAPServicesHasService(t *testing.T) {
	vcapServices := frameworks.VCAPServices{
		"newrelic": []frameworks.VCAPService{
			{Name: "newrelic-service", Label: "newrelic"},
		},
	}

	if !vcapServices.HasService("newrelic") {
		t.Error("Expected HasService to return true for 'newrelic'")
	}

	if vcapServices.HasService("appdynamics") {
		t.Error("Expected HasService to return false for 'appdynamics'")
	}
}

// TestVCAPServicesGetService tests the GetService method
func TestVCAPServicesGetService(t *testing.T) {
	vcapServices := frameworks.VCAPServices{
		"newrelic": []frameworks.VCAPService{
			{Name: "my-newrelic", Label: "newrelic"},
		},
	}

	service := vcapServices.GetService("newrelic")
	if service == nil {
		t.Fatal("Expected GetService to return a service")
	}

	if service.Name != "my-newrelic" {
		t.Errorf("Expected service name 'my-newrelic', got '%s'", service.Name)
	}

	nilService := vcapServices.GetService("appdynamics")
	if nilService != nil {
		t.Error("Expected GetService to return nil for non-existent service")
	}
}

// TestVCAPServicesHasTag tests the HasTag method
func TestVCAPServicesHasTag(t *testing.T) {
	vcapServices := frameworks.VCAPServices{
		"user-provided": []frameworks.VCAPService{
			{
				Name:  "my-monitoring",
				Label: "user-provided",
				Tags:  []string{"monitoring", "apm"},
			},
		},
	}

	if !vcapServices.HasTag("apm") {
		t.Error("Expected HasTag to return true for 'apm'")
	}

	if vcapServices.HasTag("database") {
		t.Error("Expected HasTag to return false for 'database'")
	}
}

// TestGetVCAPServicesEmpty tests parsing empty VCAP_SERVICES
func TestGetVCAPServicesEmpty(t *testing.T) {
	os.Setenv("VCAP_SERVICES", "")
	defer os.Unsetenv("VCAP_SERVICES")

	services, err := frameworks.GetVCAPServices()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}

	if len(services) != 0 {
		t.Errorf("Expected empty services map, got: %d services", len(services))
	}
}

// TestGetVCAPServicesValid tests parsing valid VCAP_SERVICES JSON
func TestGetVCAPServicesValid(t *testing.T) {
	vcapJSON := `{
		"newrelic": [{
			"name": "newrelic-service",
			"label": "newrelic",
			"tags": ["apm", "monitoring"],
			"credentials": {
				"licenseKey": "test-key-123"
			}
		}]
	}`

	os.Setenv("VCAP_SERVICES", vcapJSON)
	defer os.Unsetenv("VCAP_SERVICES")

	services, err := frameworks.GetVCAPServices()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}

	if !services.HasService("newrelic") {
		t.Error("Expected to find newrelic service")
	}

	service := services.GetService("newrelic")
	if service == nil {
		t.Fatal("Expected to get newrelic service")
	}

	if service.Name != "newrelic-service" {
		t.Errorf("Expected service name 'newrelic-service', got '%s'", service.Name)
	}

	if licenseKey, ok := service.Credentials["licenseKey"].(string); !ok || licenseKey != "test-key-123" {
		t.Error("Expected licenseKey credential to be 'test-key-123'")
	}
}

// TestFrameworkRegistry tests the framework registry
func TestFrameworkRegistry(t *testing.T) {
	// Create mock context
	stager := &libbuildpack.Stager{}
	manifest := &libbuildpack.Manifest{}
	installer := &libbuildpack.Installer{}
	logger := &libbuildpack.Logger{}
	command := &libbuildpack.Command{}

	ctx := &frameworks.Context{
		Stager:    stager,
		Manifest:  manifest,
		Installer: installer,
		Log:       logger,
		Command:   command,
	}

	// Create registry and register frameworks
	registry := frameworks.NewRegistry(ctx)
	registry.Register(frameworks.NewNewRelicFramework(ctx))
	registry.Register(frameworks.NewAppDynamicsFramework(ctx))
	registry.Register(frameworks.NewDynatraceFramework(ctx))

	// Test detection with no services (should detect nothing)
	os.Unsetenv("VCAP_SERVICES")
	detected, names, err := registry.DetectAll()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}

	if len(detected) != 0 {
		t.Errorf("Expected no frameworks detected, got: %v", names)
	}
}

// TestNewRelicFrameworkDetect tests New Relic framework detection
func TestNewRelicFrameworkDetect(t *testing.T) {
	// Create a temporary build directory for testing
	tmpDir, err := os.MkdirTemp("", "java-buildpack-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	logger := libbuildpack.NewLogger(os.Stdout)
	stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, &libbuildpack.Manifest{})

	ctx := &frameworks.Context{
		Stager: stager,
		Log:    logger,
	}

	framework := frameworks.NewNewRelicFramework(ctx)

	// Test with no service binding
	os.Unsetenv("VCAP_SERVICES")
	name, err := framework.Detect()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if name != "" {
		t.Errorf("Expected no detection without service, got: %s", name)
	}

	// Test with New Relic service
	vcapJSON := `{
		"newrelic": [{
			"name": "newrelic-service",
			"label": "newrelic",
			"credentials": {
				"licenseKey": "test-key"
			}
		}]
	}`
	os.Setenv("VCAP_SERVICES", vcapJSON)
	defer os.Unsetenv("VCAP_SERVICES")

	name, err = framework.Detect()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if name != "New Relic Agent" {
		t.Errorf("Expected 'New Relic Agent', got: %s", name)
	}
}

// TestAppDynamicsFrameworkDetect tests AppDynamics framework detection
func TestAppDynamicsFrameworkDetect(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "java-buildpack-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	logger := libbuildpack.NewLogger(os.Stdout)
	stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, &libbuildpack.Manifest{})

	ctx := &frameworks.Context{
		Stager: stager,
		Log:    logger,
	}

	framework := frameworks.NewAppDynamicsFramework(ctx)

	// Test with no service binding
	os.Unsetenv("VCAP_SERVICES")
	name, err := framework.Detect()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if name != "" {
		t.Errorf("Expected no detection without service, got: %s", name)
	}

	// Test with AppDynamics service
	vcapJSON := `{
		"appdynamics": [{
			"name": "appdynamics-service",
			"label": "appdynamics",
			"credentials": {
				"host-name": "controller.example.com",
				"account-name": "test-account",
				"account-access-key": "test-key"
			}
		}]
	}`
	os.Setenv("VCAP_SERVICES", vcapJSON)
	defer os.Unsetenv("VCAP_SERVICES")

	name, err = framework.Detect()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if name != "AppDynamics Agent" {
		t.Errorf("Expected 'AppDynamics Agent', got: %s", name)
	}
}

// TestDynatraceFrameworkDetect tests Dynatrace framework detection
func TestDynatraceFrameworkDetect(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "java-buildpack-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	logger := libbuildpack.NewLogger(os.Stdout)
	stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, &libbuildpack.Manifest{})

	ctx := &frameworks.Context{
		Stager: stager,
		Log:    logger,
	}

	framework := frameworks.NewDynatraceFramework(ctx)

	// Test with no service binding
	os.Unsetenv("VCAP_SERVICES")
	name, err := framework.Detect()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if name != "" {
		t.Errorf("Expected no detection without service, got: %s", name)
	}

	// Test with Dynatrace service
	vcapJSON := `{
		"dynatrace": [{
			"name": "dynatrace-service",
			"label": "dynatrace",
			"credentials": {
				"environmentid": "test-env",
				"apitoken": "test-token"
			}
		}]
	}`
	os.Setenv("VCAP_SERVICES", vcapJSON)
	defer os.Unsetenv("VCAP_SERVICES")

	name, err = framework.Detect()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if name != "Dynatrace OneAgent" {
		t.Errorf("Expected 'Dynatrace OneAgent', got: %s", name)
	}
}

// TestVCAPServicesMultipleServices tests handling multiple services
func TestVCAPServicesMultipleServices(t *testing.T) {
	vcapJSON := `{
		"newrelic": [{
			"name": "newrelic-1",
			"label": "newrelic"
		}, {
			"name": "newrelic-2",
			"label": "newrelic"
		}],
		"appdynamics": [{
			"name": "appdynamics-1",
			"label": "appdynamics"
		}]
	}`

	os.Setenv("VCAP_SERVICES", vcapJSON)
	defer os.Unsetenv("VCAP_SERVICES")

	services, err := frameworks.GetVCAPServices()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}

	// Should have both service types
	if !services.HasService("newrelic") {
		t.Error("Expected to find newrelic service")
	}
	if !services.HasService("appdynamics") {
		t.Error("Expected to find appdynamics service")
	}

	// GetService should return first service in array
	nrService := services.GetService("newrelic")
	if nrService == nil {
		t.Fatal("Expected to get newrelic service")
	}
	if nrService.Name != "newrelic-1" {
		t.Errorf("Expected first service 'newrelic-1', got '%s'", nrService.Name)
	}
}

// TestVCAPServicesUserProvidedWithTags tests user-provided services with tags
func TestVCAPServicesUserProvidedWithTags(t *testing.T) {
	vcapJSON := `{
		"user-provided": [{
			"name": "my-apm",
			"label": "user-provided",
			"tags": ["apm", "newrelic", "monitoring"],
			"credentials": {
				"licenseKey": "user-key"
			}
		}]
	}`

	os.Setenv("VCAP_SERVICES", vcapJSON)
	defer os.Unsetenv("VCAP_SERVICES")

	services, err := frameworks.GetVCAPServices()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}

	// Test HasTag with various tags
	if !services.HasTag("apm") {
		t.Error("Expected to find 'apm' tag")
	}
	if !services.HasTag("newrelic") {
		t.Error("Expected to find 'newrelic' tag")
	}
	if !services.HasTag("monitoring") {
		t.Error("Expected to find 'monitoring' tag")
	}
	if services.HasTag("database") {
		t.Error("Expected NOT to find 'database' tag")
	}
}

// TestVCAPServicesInvalidJSON tests handling of invalid JSON
func TestVCAPServicesInvalidJSON(t *testing.T) {
	os.Setenv("VCAP_SERVICES", `{invalid json}`)
	defer os.Unsetenv("VCAP_SERVICES")

	services, err := frameworks.GetVCAPServices()
	if err == nil {
		t.Error("Expected error for invalid JSON")
	}
	if services != nil {
		t.Error("Expected nil services for invalid JSON")
	}
}

// TestFrameworkDetectAllWithMultipleFrameworks tests detecting multiple frameworks
func TestFrameworkDetectAllWithMultipleFrameworks(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "java-buildpack-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	logger := libbuildpack.NewLogger(os.Stdout)
	stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, &libbuildpack.Manifest{})

	ctx := &frameworks.Context{
		Stager: stager,
		Log:    logger,
	}

	// Create registry with multiple frameworks
	registry := frameworks.NewRegistry(ctx)
	registry.Register(frameworks.NewNewRelicFramework(ctx))
	registry.Register(frameworks.NewAppDynamicsFramework(ctx))
	registry.Register(frameworks.NewDynatraceFramework(ctx))

	// Set up VCAP_SERVICES with multiple APM services
	vcapJSON := `{
		"newrelic": [{
			"name": "newrelic-service",
			"label": "newrelic",
			"credentials": {"licenseKey": "test-key"}
		}],
		"appdynamics": [{
			"name": "appdynamics-service",
			"label": "appdynamics",
			"credentials": {"account-access-key": "test-key"}
		}]
	}`
	os.Setenv("VCAP_SERVICES", vcapJSON)
	defer os.Unsetenv("VCAP_SERVICES")

	detected, names, err := registry.DetectAll()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}

	// Should detect both New Relic and AppDynamics
	if len(detected) != 2 {
		t.Errorf("Expected 2 frameworks detected, got: %d (%v)", len(detected), names)
	}

	// Check that names are correct
	expectedNames := map[string]bool{
		"New Relic Agent":   false,
		"AppDynamics Agent": false,
	}

	for _, name := range names {
		if _, ok := expectedNames[name]; ok {
			expectedNames[name] = true
		}
	}

	for name, found := range expectedNames {
		if !found {
			t.Errorf("Expected to detect '%s' but did not", name)
		}
	}
}

// TestVCAPServicesEmptyCredentials tests service with empty credentials
func TestVCAPServicesEmptyCredentials(t *testing.T) {
	vcapJSON := `{
		"newrelic": [{
			"name": "newrelic-service",
			"label": "newrelic",
			"credentials": {}
		}]
	}`

	os.Setenv("VCAP_SERVICES", vcapJSON)
	defer os.Unsetenv("VCAP_SERVICES")

	services, err := frameworks.GetVCAPServices()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}

	if !services.HasService("newrelic") {
		t.Error("Expected to find newrelic service even with empty credentials")
	}

	service := services.GetService("newrelic")
	if service == nil {
		t.Fatal("Expected to get service")
	}

	if service.Credentials == nil {
		t.Error("Expected credentials map to exist (even if empty)")
	}

	if len(service.Credentials) != 0 {
		t.Error("Expected empty credentials map")
	}
}

// ==============================================================================
// NOTE: Supply() and Finalize() Testing Strategy
// ==============================================================================
//
// Supply() and Finalize() methods are NOT unit tested here because they require:
// 1. Real manifest.yml with valid dependency entries
// 2. Actual file downloads via Installer.InstallDependency()
// 3. Real filesystem operations in deps directory
//
// These methods should be tested via:
// - Integration tests (src/java/integration/) with real packaged buildpack
// - BRATS tests that deploy actual applications
//
// Unit tests focus on:
// ✅ Detection logic (VCAP_SERVICES parsing, environment detection)
// ✅ VCAP_SERVICES parsing and credential extraction
// ✅ Framework registry operations
//
// Coverage goal: Focus on testable components (40%+ achievable with detection tests)
//  Current coverage breakdown:
//   - Detect() methods: ~71% (good coverage via unit tests)
//   - Supply() methods: 0% (requires integration tests)
//   - Finalize() methods: 0% (requires integration tests)
//
// To achieve better coverage, add:
// - More VCAP_SERVICES parsing edge cases
// - Framework registry error handling tests
// - Credential validation tests (without actual installation)
// ==============================================================================

// TestJavaOptsFrameworkDetect tests Java Opts framework detection
func TestJavaOptsFrameworkDetect(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "java-buildpack-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	logger := libbuildpack.NewLogger(os.Stdout)
	manifest := &libbuildpack.Manifest{}
	stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, manifest)

	ctx := &frameworks.Context{
		Stager:   stager,
		Manifest: manifest,
		Log:      logger,
	}

	framework := frameworks.NewJavaOptsFramework(ctx)

	// Test with no configuration (from_environment: true by default)
	os.Unsetenv("JBP_CONFIG_JAVA_OPTS")
	name, err := framework.Detect()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if name != "Java Opts" {
		t.Errorf("Expected 'Java Opts' (from_environment: true by default), got: %s", name)
	}

	// Test with JBP_CONFIG_JAVA_OPTS environment variable
	os.Setenv("JBP_CONFIG_JAVA_OPTS", "{java_opts: [\"-Xmx512m\"]}")
	defer os.Unsetenv("JBP_CONFIG_JAVA_OPTS")

	name, err = framework.Detect()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if name != "Java Opts" {
		t.Errorf("Expected 'Java Opts', got: %s", name)
	}
}

// TestJavaOptsFrameworkSupply tests Java Opts framework supply (should be no-op)
func TestJavaOptsFrameworkSupply(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "java-buildpack-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	logger := libbuildpack.NewLogger(os.Stdout)
	manifest := &libbuildpack.Manifest{}
	stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, manifest)

	ctx := &frameworks.Context{
		Stager:   stager,
		Manifest: manifest,
		Log:      logger,
	}

	framework := frameworks.NewJavaOptsFramework(ctx)

	// Supply should be a no-op (no error)
	err = framework.Supply()
	if err != nil {
		t.Errorf("Expected no error from Supply(), got: %v", err)
	}
}

// TestJavaOptsConfigParsing tests parsing of java_opts configuration
func TestJavaOptsConfigParsing(t *testing.T) {
	// Test with custom java_opts
	os.Setenv("JBP_CONFIG_JAVA_OPTS", "{java_opts: [\"-Xmx512m\", \"-XX:+UseG1GC\"]}")
	defer os.Unsetenv("JBP_CONFIG_JAVA_OPTS")

	tmpDir, err := os.MkdirTemp("", "java-buildpack-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	logger := libbuildpack.NewLogger(os.Stdout)
	manifest := &libbuildpack.Manifest{}
	stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, manifest)

	ctx := &frameworks.Context{
		Stager:   stager,
		Manifest: manifest,
		Log:      logger,
	}

	framework := frameworks.NewJavaOptsFramework(ctx)

	// Should detect with custom opts
	name, err := framework.Detect()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if name != "Java Opts" {
		t.Errorf("Expected 'Java Opts', got: %s", name)
	}
}

// TestJavaOptsFromEnvironmentDisabled tests behavior when from_environment is false
func TestJavaOptsFromEnvironmentDisabled(t *testing.T) {
	// Disable from_environment
	os.Setenv("JBP_CONFIG_JAVA_OPTS", "{from_environment: false}")
	defer os.Unsetenv("JBP_CONFIG_JAVA_OPTS")

	tmpDir, err := os.MkdirTemp("", "java-buildpack-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	logger := libbuildpack.NewLogger(os.Stdout)
	manifest := &libbuildpack.Manifest{}
	stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, manifest)

	ctx := &frameworks.Context{
		Stager:   stager,
		Manifest: manifest,
		Log:      logger,
	}

	framework := frameworks.NewJavaOptsFramework(ctx)

	// Should not detect when from_environment is false and no custom opts
	name, err := framework.Detect()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if name != "" {
		t.Errorf("Expected no detection when from_environment is false, got: %s", name)
	}
}

// TestSpringAutoReconfigurationDetect tests Spring Auto-reconfiguration detection
func TestSpringAutoReconfigurationDetect(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "java-buildpack-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create BOOT-INF/lib directory structure
	bootInfLib := filepath.Join(tmpDir, "BOOT-INF", "lib")
	if err := os.MkdirAll(bootInfLib, 0755); err != nil {
		t.Fatalf("Failed to create BOOT-INF/lib: %v", err)
	}

	// Create spring-core JAR
	springCoreJar := filepath.Join(bootInfLib, "spring-core-5.3.29.jar")
	if err := os.WriteFile(springCoreJar, []byte("fake jar"), 0644); err != nil {
		t.Fatalf("Failed to create spring-core JAR: %v", err)
	}

	logger := libbuildpack.NewLogger(os.Stdout)
	manifest := &libbuildpack.Manifest{}
	stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, manifest)

	// Enable Spring Auto-reconfiguration explicitly (now disabled by default)
	os.Setenv("JBP_CONFIG_SPRING_AUTO_RECONFIGURATION", "{enabled: true}")
	defer os.Unsetenv("JBP_CONFIG_SPRING_AUTO_RECONFIGURATION")

	ctx := &frameworks.Context{
		Stager:   stager,
		Manifest: manifest,
		Log:      logger,
	}

	framework := frameworks.NewSpringAutoReconfigurationFramework(ctx)

	// Should detect Spring application when explicitly enabled
	name, err := framework.Detect()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if name != "Spring Auto-reconfiguration" {
		t.Errorf("Expected 'Spring Auto-reconfiguration', got: %s", name)
	}
}

// TestSpringAutoReconfigurationNoSpring tests no detection without Spring
func TestSpringAutoReconfigurationNoSpring(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "java-buildpack-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	logger := libbuildpack.NewLogger(os.Stdout)
	manifest := &libbuildpack.Manifest{}
	stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, manifest)

	ctx := &frameworks.Context{
		Stager:   stager,
		Manifest: manifest,
		Log:      logger,
	}

	framework := frameworks.NewSpringAutoReconfigurationFramework(ctx)

	// Should not detect without Spring
	name, err := framework.Detect()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if name != "" {
		t.Errorf("Expected no detection without Spring, got: %s", name)
	}
}

// TestSpringAutoReconfigurationSkipWithJavaCfEnv tests skipping when java-cfenv is present
func TestSpringAutoReconfigurationSkipWithJavaCfEnv(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "java-buildpack-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create BOOT-INF/lib directory structure
	bootInfLib := filepath.Join(tmpDir, "BOOT-INF", "lib")
	if err := os.MkdirAll(bootInfLib, 0755); err != nil {
		t.Fatalf("Failed to create BOOT-INF/lib: %v", err)
	}

	// Create both spring-core and java-cfenv JARs
	springCoreJar := filepath.Join(bootInfLib, "spring-core-5.3.29.jar")
	if err := os.WriteFile(springCoreJar, []byte("fake jar"), 0644); err != nil {
		t.Fatalf("Failed to create spring-core JAR: %v", err)
	}

	javaCfEnvJar := filepath.Join(bootInfLib, "java-cfenv-boot-3.1.5.jar")
	if err := os.WriteFile(javaCfEnvJar, []byte("fake jar"), 0644); err != nil {
		t.Fatalf("Failed to create java-cfenv JAR: %v", err)
	}

	logger := libbuildpack.NewLogger(os.Stdout)
	manifest := &libbuildpack.Manifest{}
	stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, manifest)

	ctx := &frameworks.Context{
		Stager:   stager,
		Manifest: manifest,
		Log:      logger,
	}

	framework := frameworks.NewSpringAutoReconfigurationFramework(ctx)

	// Should NOT detect when java-cfenv is present
	name, err := framework.Detect()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if name != "" {
		t.Errorf("Expected no detection with java-cfenv present, got: %s", name)
	}
}

// TestSpringAutoReconfigurationDisabled tests disabled via environment variable
func TestSpringAutoReconfigurationDisabled(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "java-buildpack-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create BOOT-INF/lib directory structure
	bootInfLib := filepath.Join(tmpDir, "BOOT-INF", "lib")
	if err := os.MkdirAll(bootInfLib, 0755); err != nil {
		t.Fatalf("Failed to create BOOT-INF/lib: %v", err)
	}

	// Create spring-core JAR
	springCoreJar := filepath.Join(bootInfLib, "spring-core-5.3.29.jar")
	if err := os.WriteFile(springCoreJar, []byte("fake jar"), 0644); err != nil {
		t.Fatalf("Failed to create spring-core JAR: %v", err)
	}

	// Disable Spring Auto-reconfiguration
	os.Setenv("JBP_CONFIG_SPRING_AUTO_RECONFIGURATION", "{enabled: false}")
	defer os.Unsetenv("JBP_CONFIG_SPRING_AUTO_RECONFIGURATION")

	logger := libbuildpack.NewLogger(os.Stdout)
	manifest := &libbuildpack.Manifest{}
	stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, manifest)

	ctx := &frameworks.Context{
		Stager:   stager,
		Manifest: manifest,
		Log:      logger,
	}

	framework := frameworks.NewSpringAutoReconfigurationFramework(ctx)

	// Should NOT detect when explicitly disabled
	name, err := framework.Detect()
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if name != "" {
		t.Errorf("Expected no detection when disabled, got: %s", name)
	}
}

// TestJavaOptsLegacyFormat tests backward compatibility with legacy YAML format
// Issue: https://github.com/cloudfoundry/java-buildpack/issues/1133
func TestJavaOptsLegacyFormat(t *testing.T) {
	// Test legacy format: [from_environment: false, java_opts: -Xmx512M -Xms256M ...]
	// This was accepted by the Ruby buildpack
	os.Setenv("JBP_CONFIG_JAVA_OPTS", "[from_environment: false, java_opts: -Xmx512M -Xms256M -Xss1M -XX:MetaspaceSize=157286K -XX:MaxMetaspaceSize=314572K -DoptionKey=optionValue]")
	defer os.Unsetenv("JBP_CONFIG_JAVA_OPTS")

	tmpDir, err := os.MkdirTemp("", "java-buildpack-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create deps directory for the stager
	depsDir := filepath.Join(tmpDir, "deps")
	if err := os.MkdirAll(filepath.Join(depsDir, "0"), 0755); err != nil {
		t.Fatalf("Failed to create deps dir: %v", err)
	}

	logger := libbuildpack.NewLogger(os.Stdout)
	manifest := &libbuildpack.Manifest{}
	stager := libbuildpack.NewStager([]string{tmpDir, "", depsDir, "0"}, logger, manifest)

	ctx := &frameworks.Context{
		Stager:   stager,
		Manifest: manifest,
		Log:      logger,
	}

	framework := frameworks.NewJavaOptsFramework(ctx)

	// Should detect with legacy format
	name, err := framework.Detect()
	if err != nil {
		t.Fatalf("Expected no error with legacy format, got: %v", err)
	}
	if name != "Java Opts" {
		t.Errorf("Expected 'Java Opts', got: %s", name)
	}

	// Verify the opts were parsed correctly
	err = framework.Finalize()
	if err != nil {
		t.Fatalf("Expected no error from Finalize(), got: %v", err)
	}

	// Read the JAVA_OPTS .opts file (written to depsDir/0/java_opts/99_user_java_opts.opts)
	// With the new centralized JAVA_OPTS assembly, opts are written to .opts files
	optsFile := filepath.Join(depsDir, "0", "java_opts", "99_user_java_opts.opts")
	data, err := os.ReadFile(optsFile)
	if err != nil {
		t.Fatalf("Failed to read JAVA_OPTS .opts file: %v", err)
	}

	javaOpts := string(data)
	expectedOpts := []string{"-Xmx512M", "-Xms256M", "-Xss1M", "-XX:MetaspaceSize=157286K", "-XX:MaxMetaspaceSize=314572K", "-DoptionKey=optionValue"}

	for _, opt := range expectedOpts {
		if !strings.Contains(javaOpts, opt) {
			t.Errorf("Expected JAVA_OPTS to contain %s, got: %s", opt, javaOpts)
		}
	}
}
