# Testing Guide

This guide covers testing strategies, patterns, and best practices for the Cloud Foundry Java Buildpack. The buildpack uses a comprehensive test suite with both unit tests and integration tests.

## Table of Contents

- [Overview](#overview)
- [Test Frameworks](#test-frameworks)
- [Unit Testing](#unit-testing)
- [Integration Testing](#integration-testing)
- [Testing Patterns](#testing-patterns)
- [Mocking and Stubbing](#mocking-and-stubbing)
- [Test Coverage](#test-coverage)
- [Running Tests](#running-tests)
- [Writing New Tests](#writing-new-tests)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

### Test Types

The buildpack has two main types of tests:

1. **Unit Tests** - Test individual components in isolation
   - Fast execution (~30 seconds for full suite)
   - No external dependencies required
   - Located in `src/java/**/*_test.go`

2. **Integration Tests** - Test complete buildpack behavior
   - Slower execution (~5-15 minutes)
   - Require packaged buildpack and Docker/CF
   - Located in `src/integration/*_test.go`

### Test Coverage

As of December 2024:
- **427 unit tests** covering containers, frameworks, and JREs
- **50+ integration tests** covering all container types and major frameworks
- **~85% code coverage** across core components

## Test Frameworks

### Ginkgo v2

The primary test framework used for BDD-style tests.

**Installation:**
```bash
go install github.com/onsi/ginkgo/v2/ginkgo@latest
```

**Why Ginkgo?**
- Clean, readable BDD syntax
- Excellent test organization with `Describe` and `Context` blocks
- Built-in parallel test execution
- Great integration with Gomega matchers

**Example:**
```go
var _ = Describe("MyComponent", func() {
    Context("when configured correctly", func() {
        It("should succeed", func() {
            Expect(result).To(BeTrue())
        })
    })
})
```

### Gomega

Assertion library with expressive matchers.

**Common Matchers:**
```go
Expect(value).To(Equal(expected))
Expect(value).NotTo(BeNil())
Expect(string).To(ContainSubstring("text"))
Expect(err).NotTo(HaveOccurred())
Expect(slice).To(HaveLen(5))
Expect(path).To(BeAnExistingFile())
```

### Standard Testing Package

Used for simple unit tests that don't require BDD structure.

**Example:**
```go
func TestMyFunction(t *testing.T) {
    result := MyFunction()
    if result != expected {
        t.Errorf("Expected %v, got %v", expected, result)
    }
}
```

### Switchblade

Integration testing framework for Cloud Foundry buildpacks.

**Features:**
- Deploy to Docker or Cloud Foundry
- Test with real applications
- Validate responses and logs
- Parallel test execution

## Unit Testing

### Test File Structure

Unit tests follow Go conventions:

```
src/java/
├── containers/
│   ├── spring_boot.go
│   ├── spring_boot_test.go       # Tests for spring_boot.go
│   ├── tomcat.go
│   └── tomcat_test.go
├── frameworks/
│   ├── new_relic.go
│   └── framework_test.go         # Tests for all frameworks
└── jres/
    ├── open_jdk.go
    └── open_jdk_test.go
```

### Basic Unit Test Structure (Standard Go)

**File:** `src/java/frameworks/framework_test.go`

```go
package frameworks_test

import (
    "os"
    "testing"
    "github.com/cloudfoundry/java-buildpack/src/java/frameworks"
    "github.com/cloudfoundry/libbuildpack"
)

func TestMyFrameworkDetect(t *testing.T) {
    // Setup: Create test context
    tmpDir, err := os.MkdirTemp("", "test-*")
    if err != nil {
        t.Fatalf("Failed to create temp dir: %v", err)
    }
    defer os.RemoveAll(tmpDir)
    
    logger := libbuildpack.NewLogger(os.Stdout)
    stager := libbuildpack.NewStager(
        []string{tmpDir, "", "0"}, 
        logger, 
        &libbuildpack.Manifest{},
    )
    
    ctx := &frameworks.Context{
        Stager: stager,
        Log:    logger,
    }
    
    framework := frameworks.NewMyFramework(ctx)
    
    // Test: Execute detection
    name, err := framework.Detect()
    
    // Assert: Verify results
    if err != nil {
        t.Fatalf("Unexpected error: %v", err)
    }
    
    if name != "my-framework" {
        t.Errorf("Expected 'my-framework', got: %s", name)
    }
}
```

### Ginkgo/Gomega Unit Test Structure

**File:** `src/java/containers/container_test.go`

```go
package containers_test

import (
    "os"
    "path/filepath"
    "testing"
    
    "github.com/cloudfoundry/java-buildpack/src/java/containers"
    "github.com/cloudfoundry/libbuildpack"
    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
)

func TestContainers(t *testing.T) {
    RegisterFailHandler(Fail)
    RunSpecs(t, "Containers Suite")
}

var _ = Describe("Spring Boot Container", func() {
    var (
        ctx      *containers.Context
        buildDir string
        depsDir  string
    )
    
    BeforeEach(func() {
        var err error
        buildDir, err = os.MkdirTemp("", "build")
        Expect(err).NotTo(HaveOccurred())
        
        depsDir, err = os.MkdirTemp("", "deps")
        Expect(err).NotTo(HaveOccurred())
        
        logger := libbuildpack.NewLogger(os.Stdout)
        stager := libbuildpack.NewStager(
            []string{buildDir, "", depsDir, "0"},
            logger,
            &libbuildpack.Manifest{},
        )
        
        ctx = &containers.Context{
            Stager: stager,
            Log:    logger,
        }
    })
    
    AfterEach(func() {
        os.RemoveAll(buildDir)
        os.RemoveAll(depsDir)
    })
    
    Context("with BOOT-INF directory", func() {
        BeforeEach(func() {
            // Create Spring Boot structure
            os.MkdirAll(filepath.Join(buildDir, "BOOT-INF"), 0755)
            os.MkdirAll(filepath.Join(buildDir, "META-INF"), 0755)
            
            manifest := "Start-Class: com.example.App\n"
            manifestPath := filepath.Join(buildDir, "META-INF", "MANIFEST.MF")
            os.WriteFile(manifestPath, []byte(manifest), 0644)
        })
        
        It("detects as Spring Boot", func() {
            container := containers.NewSpringBootContainer(ctx)
            name, err := container.Detect()
            
            Expect(err).NotTo(HaveOccurred())
            Expect(name).To(Equal("Spring Boot"))
        })
    })
    
    Context("without Spring Boot indicators", func() {
        It("does not detect", func() {
            container := containers.NewSpringBootContainer(ctx)
            name, err := container.Detect()
            
            Expect(err).NotTo(HaveOccurred())
            Expect(name).To(BeEmpty())
        })
    })
})
```

### Testing with VCAP_SERVICES

Many frameworks detect based on bound services. Test this pattern:

```go
func TestServiceBoundFramework(t *testing.T) {
    // Setup: Create VCAP_SERVICES JSON
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
    
    // Set environment variable
    os.Setenv("VCAP_SERVICES", vcapJSON)
    defer os.Unsetenv("VCAP_SERVICES")
    
    // Test framework detection
    ctx := createTestContext(t)
    framework := frameworks.NewNewRelicFramework(ctx)
    
    name, err := framework.Detect()
    if err != nil {
        t.Fatalf("Unexpected error: %v", err)
    }
    
    if name != "New Relic Agent" {
        t.Errorf("Expected 'New Relic Agent', got: %s", name)
    }
    
    // Verify credentials parsing
    services, _ := frameworks.GetVCAPServices()
    service := services.GetService("newrelic")
    
    licenseKey := service.Credentials["licenseKey"].(string)
    if licenseKey != "test-key-123" {
        t.Errorf("Expected license key 'test-key-123', got: %s", licenseKey)
    }
}
```

### Testing File-Based Detection

Test components that detect based on file presence:

```go
func TestFileBasedDetection(t *testing.T) {
    tmpDir, _ := os.MkdirTemp("", "test-*")
    defer os.RemoveAll(tmpDir)
    
    // Create marker file that triggers detection
    markerPath := filepath.Join(tmpDir, "WEB-INF", "web.xml")
    os.MkdirAll(filepath.Dir(markerPath), 0755)
    os.WriteFile(markerPath, []byte("<web-app/>"), 0644)
    
    // Create test context with temp directory as build dir
    logger := libbuildpack.NewLogger(os.Stdout)
    stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, &libbuildpack.Manifest{})
    
    ctx := &containers.Context{
        Stager: stager,
        Log:    logger,
    }
    
    // Test detection
    container := containers.NewTomcatContainer(ctx)
    name, err := container.Detect()
    
    if err != nil {
        t.Fatalf("Unexpected error: %v", err)
    }
    
    if name != "Tomcat" {
        t.Errorf("Expected 'Tomcat', got: %s", name)
    }
}
```

### Testing Configuration Parsing

Test components that parse configuration from environment variables:

```go
func TestConfigurationParsing(t *testing.T) {
    tests := []struct {
        name     string
        envValue string
        expected bool
    }{
        {
            name:     "enabled explicitly",
            envValue: "{enabled: true}",
            expected: true,
        },
        {
            name:     "disabled explicitly",
            envValue: "{enabled: false}",
            expected: false,
        },
        {
            name:     "empty config",
            envValue: "",
            expected: false,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            os.Setenv("JBP_CONFIG_DEBUG", tt.envValue)
            defer os.Unsetenv("JBP_CONFIG_DEBUG")
            
            ctx := createTestContext(t)
            framework := frameworks.NewDebugFramework(ctx)
            
            name, _ := framework.Detect()
            detected := name != ""
            
            if detected != tt.expected {
                t.Errorf("Expected detected=%v, got %v", tt.expected, detected)
            }
        })
    }
}
```

## Integration Testing

### Integration Test Structure

**File:** `src/integration/spring_boot_test.go`

```go
package integration_test

import (
    "path/filepath"
    "testing"
    
    "github.com/cloudfoundry/switchblade"
    "github.com/cloudfoundry/switchblade/matchers"
    "github.com/sclevine/spec"
    
    . "github.com/onsi/gomega"
)

func testSpringBoot(platform switchblade.Platform, fixtures string) func(*testing.T, spec.G, spec.S) {
    return func(t *testing.T, context spec.G, it spec.S) {
        var (
            Expect     = NewWithT(t).Expect
            Eventually = NewWithT(t).Eventually
            name       string
        )
        
        it.Before(func() {
            var err error
            name, err = switchblade.RandomName()
            Expect(err).NotTo(HaveOccurred())
        })
        
        it.After(func() {
            if name != "" && (!settings.KeepFailedContainers || !t.Failed()) {
                Expect(platform.Delete.Execute(name)).To(Succeed())
            }
        })
        
        context("with a Spring Boot application", func() {
            it("successfully deploys and runs", func() {
                deployment, logs, err := platform.Deploy.
                    WithEnv(map[string]string{
                        "BP_JAVA_VERSION": "11",
                    }).
                    Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
                    
                Expect(err).NotTo(HaveOccurred(), logs.String)
                Expect(logs.String()).To(ContainSubstring("Java Buildpack"))
                Eventually(deployment).Should(matchers.Serve(Not(BeEmpty())))
            })
        })
    }
}
```

### Integration Test Setup

**File:** `src/integration/init_test.go`

```go
package integration_test

import (
    "flag"
    "os"
    "testing"
    "time"
    
    "github.com/cloudfoundry/switchblade"
    "github.com/sclevine/spec"
    "github.com/sclevine/spec/report"
    
    . "github.com/onsi/gomega"
)

var settings struct {
    Cached               bool
    Serial               bool
    KeepFailedContainers bool
    Platform             string
    Stack                string
    GitHubToken          string
}

func init() {
    flag.BoolVar(&settings.Cached, "cached", false, "run cached buildpack tests")
    flag.BoolVar(&settings.Serial, "serial", false, "run tests serially")
    flag.BoolVar(&settings.KeepFailedContainers, "keep-failed-containers", false, "preserve failed containers")
    flag.StringVar(&settings.Platform, "platform", "cf", `platform to test ("cf" or "docker")`)
    flag.StringVar(&settings.Stack, "stack", "cflinuxfs4", "stack to use")
    flag.StringVar(&settings.GitHubToken, "github-token", "", "GitHub API token")
}

func TestIntegration(t *testing.T) {
    var Expect = NewWithT(t).Expect
    
    SetDefaultEventuallyTimeout(20 * time.Second)
    
    // Get buildpack file from environment
    buildpackFile := os.Getenv("BUILDPACK_FILE")
    if buildpackFile == "" {
        t.Fatal("BUILDPACK_FILE environment variable is required")
    }
    
    // Initialize platform
    platform, err := switchblade.NewPlatform(settings.Platform, settings.GitHubToken, settings.Stack)
    Expect(err).NotTo(HaveOccurred())
    
    err = platform.Initialize(
        switchblade.Buildpack{
            Name: "java_buildpack",
            URI:  buildpackFile,
        },
    )
    Expect(err).NotTo(HaveOccurred())
    
    // Create test suite
    var suite spec.Suite
    if settings.Serial {
        suite = spec.New("integration", spec.Report(report.Terminal{}), spec.Sequential())
    } else {
        suite = spec.New("integration", spec.Report(report.Terminal{}), spec.Parallel())
    }
    
    // Register test suites
    suite("SpringBoot", testSpringBoot(platform, fixtures))
    suite("Tomcat", testTomcat(platform, fixtures))
    suite("JavaMain", testJavaMain(platform, fixtures))
    suite("Frameworks", testFrameworks(platform, fixtures))
    
    suite.Run(t)
    
    Expect(platform.Deinitialize()).To(Succeed())
}
```

### Running Integration Tests

**Prerequisites:**
1. Package the buildpack
2. Set BUILDPACK_FILE environment variable
3. Have Docker running (for Docker platform tests)

**Commands:**

```bash
# Package buildpack
./scripts/package.sh --version dev

# Run integration tests with Docker
export BUILDPACK_FILE="${PWD}/build/buildpack.zip"
./scripts/integration.sh --platform docker

# Run in parallel (faster)
./scripts/integration.sh --platform docker --parallel true

# Keep failed containers for debugging
./scripts/integration.sh --platform docker --keep-failed-containers

# Run specific test
cd src/integration
go test -v -run TestSpringBoot
```

## Testing Patterns

### Pattern 1: Table-Driven Tests

Test multiple scenarios with a single test function:

```go
func TestVersionParsing(t *testing.T) {
    tests := []struct {
        name     string
        input    string
        expected string
        wantErr  bool
    }{
        {
            name:     "valid version",
            input:    "1.2.3",
            expected: "1.2.3",
            wantErr:  false,
        },
        {
            name:     "version range",
            input:    "1.+",
            expected: "1.",
            wantErr:  false,
        },
        {
            name:     "invalid version",
            input:    "invalid",
            expected: "",
            wantErr:  true,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result, err := ParseVersion(tt.input)
            
            if tt.wantErr {
                if err == nil {
                    t.Error("Expected error, got nil")
                }
                return
            }
            
            if err != nil {
                t.Fatalf("Unexpected error: %v", err)
            }
            
            if result != tt.expected {
                t.Errorf("Expected %s, got %s", tt.expected, result)
            }
        })
    }
}
```

### Pattern 2: Setup and Teardown

Use helper functions for common setup:

```go
func createTestContext(t *testing.T) *frameworks.Context {
    tmpDir, err := os.MkdirTemp("", "test-*")
    if err != nil {
        t.Fatalf("Failed to create temp dir: %v", err)
    }
    
    t.Cleanup(func() {
        os.RemoveAll(tmpDir)
    })
    
    logger := libbuildpack.NewLogger(os.Stdout)
    stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, &libbuildpack.Manifest{})
    
    return &frameworks.Context{
        Stager: stager,
        Log:    logger,
    }
}

func TestMyFramework(t *testing.T) {
    ctx := createTestContext(t)
    framework := frameworks.NewMyFramework(ctx)
    // ... test logic
}
```

### Pattern 3: Testing with Subtests

Organize related tests with subtests:

```go
func TestFrameworkDetection(t *testing.T) {
    t.Run("with service bound", func(t *testing.T) {
        os.Setenv("VCAP_SERVICES", `{"newrelic":[{"name":"nr"}]}`)
        defer os.Unsetenv("VCAP_SERVICES")
        
        // Test detection
    })
    
    t.Run("without service", func(t *testing.T) {
        os.Unsetenv("VCAP_SERVICES")
        
        // Test no detection
    })
    
    t.Run("with invalid service", func(t *testing.T) {
        os.Setenv("VCAP_SERVICES", `{"newrelic":[]}`)
        defer os.Unsetenv("VCAP_SERVICES")
        
        // Test handling of invalid service
    })
}
```

### Pattern 4: Testing Error Conditions

Verify proper error handling:

```go
func TestErrorHandling(t *testing.T) {
    ctx := createTestContext(t)
    
    // Simulate error condition (missing required file)
    framework := frameworks.NewMyFramework(ctx)
    
    err := framework.Supply()
    if err == nil {
        t.Error("Expected error when required file is missing")
    }
    
    // Verify error message is helpful
    expectedMsg := "required file not found"
    if !strings.Contains(err.Error(), expectedMsg) {
        t.Errorf("Expected error containing '%s', got: %v", expectedMsg, err)
    }
}
```

### Pattern 5: Testing Filesystem Operations

Verify file creation, modification, and reading:

```go
func TestFileOperations(t *testing.T) {
    tmpDir, _ := os.MkdirTemp("", "test-*")
    defer os.RemoveAll(tmpDir)
    
    ctx := createTestContext(t)
    framework := frameworks.NewMyFramework(ctx)
    
    // Execute operation that creates files
    err := framework.Finalize()
    if err != nil {
        t.Fatalf("Finalize failed: %v", err)
    }
    
    // Verify file was created
    profilePath := filepath.Join(tmpDir, ".profile.d", "my_framework.sh")
    if _, err := os.Stat(profilePath); os.IsNotExist(err) {
        t.Errorf("Expected profile.d script to exist at %s", profilePath)
    }
    
    // Verify file contents
    content, _ := os.ReadFile(profilePath)
    if !strings.Contains(string(content), "export JAVA_OPTS") {
        t.Error("Profile script missing expected JAVA_OPTS export")
    }
}
```

## Mocking and Stubbing

### Mocking External Dependencies

When testing components that download files or make HTTP requests:

```go
type mockInstaller struct {
    installedDeps []string
}

func (m *mockInstaller) InstallDependency(dep libbuildpack.Dependency, targetDir string) error {
    m.installedDeps = append(m.installedDeps, dep.Name)
    // Simulate installation by creating a dummy file
    return os.WriteFile(filepath.Join(targetDir, dep.Name+".jar"), []byte("mock"), 0644)
}

func TestSupplyWithMock(t *testing.T) {
    mockInst := &mockInstaller{}
    
    ctx := &frameworks.Context{
        Stager:    createStager(t),
        Installer: mockInst,
        Log:       libbuildpack.NewLogger(os.Stdout),
    }
    
    framework := frameworks.NewMyFramework(ctx)
    err := framework.Supply()
    
    if err != nil {
        t.Fatalf("Supply failed: %v", err)
    }
    
    // Verify mock was called
    if len(mockInst.installedDeps) != 1 {
        t.Errorf("Expected 1 dependency installed, got %d", len(mockInst.installedDeps))
    }
}
```

### Stubbing Environment Variables

Use cleanup functions to ensure environment is reset:

```go
func setEnvWithCleanup(t *testing.T, key, value string) {
    old := os.Getenv(key)
    os.Setenv(key, value)
    
    t.Cleanup(func() {
        if old == "" {
            os.Unsetenv(key)
        } else {
            os.Setenv(key, old)
        }
    })
}

func TestWithEnvironment(t *testing.T) {
    setEnvWithCleanup(t, "JBP_CONFIG_DEBUG", "{enabled: true}")
    
    // Test with environment variable set
    // Cleanup happens automatically after test
}
```

## Test Coverage

### Checking Coverage

```bash
# Run tests with coverage
cd src/java
go test -cover ./containers/...
go test -cover ./frameworks/...
go test -cover ./jres/...

# Generate coverage report
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html

# View coverage in terminal
go tool cover -func=coverage.out
```

### Coverage Goals

- **Containers**: >90% coverage (high confidence in detection and launch logic)
- **Frameworks**: >85% coverage (many frameworks have similar patterns)
- **JREs**: >80% coverage (JRE installation is well-tested)
- **Utilities**: >90% coverage (critical path code)

### Improving Coverage

Identify uncovered code:

```bash
# Find uncovered lines
go test -coverprofile=coverage.out ./frameworks/...
go tool cover -func=coverage.out | grep -E "^.*\.go.*0\.0%"
```

Add tests for:
- Error conditions
- Edge cases (empty strings, nil values)
- Configuration variations
- Different file structures

## Running Tests

### Run All Unit Tests

```bash
# Using script (recommended)
./scripts/unit.sh

# Using ginkgo directly
cd src/java
ginkgo -r --skip-package=integration

# Using go test
cd src/java
go test ./...
```

### Run Specific Tests

```bash
# Test a specific package
cd src/java
ginkgo frameworks/

# Test a specific file
ginkgo frameworks/debug_test.go

# Test by name pattern
ginkgo --focus="Spring Boot" containers/

# Test with verbose output
ginkgo -v frameworks/
```

### Run Integration Tests

```bash
# Package buildpack first
./scripts/package.sh --version dev

# Run integration tests
export BUILDPACK_FILE="${PWD}/build/buildpack.zip"
./scripts/integration.sh --platform docker

# Options
./scripts/integration.sh --platform docker --parallel true
./scripts/integration.sh --platform docker --keep-failed-containers
./scripts/integration.sh --platform docker --cached true
```

### Run in Watch Mode

Automatically re-run tests when files change:

```bash
cd src/java
ginkgo watch -r frameworks/
```

### Run with Different Verbosity

```bash
# Quiet (only failures)
ginkgo -succinct frameworks/

# Verbose (all output)
ginkgo -v frameworks/

# Very verbose (includes Gomega details)
ginkgo -vv frameworks/
```

## Writing New Tests

### Checklist for New Tests

When implementing a new component, write tests for:

- [ ] **Detection**
  - [ ] Detects when conditions are met
  - [ ] Does not detect when conditions are not met
  - [ ] Handles edge cases (missing files, invalid config)

- [ ] **Supply Phase**
  - [ ] Downloads correct dependencies
  - [ ] Creates necessary directories
  - [ ] Handles download failures gracefully
  - [ ] Logs appropriate messages

- [ ] **Finalize Phase**
  - [ ] Creates profile.d scripts
  - [ ] Sets environment variables correctly
  - [ ] Generates correct JVM options
  - [ ] Handles missing files gracefully

- [ ] **Configuration**
  - [ ] Parses configuration correctly
  - [ ] Handles missing configuration
  - [ ] Handles invalid configuration
  - [ ] Respects user overrides

- [ ] **Integration**
  - [ ] Works with real applications
  - [ ] Produces correct startup command
  - [ ] Application runs successfully

### Test Template for New Framework

```go
package frameworks_test

import (
    "os"
    "testing"
    "github.com/cloudfoundry/java-buildpack/src/java/frameworks"
    "github.com/cloudfoundry/libbuildpack"
)

func TestMyNewFrameworkDetect(t *testing.T) {
    t.Run("with service bound", func(t *testing.T) {
        vcapJSON := `{
            "my-service": [{
                "name": "my-service-instance",
                "credentials": {"api_key": "test-key"}
            }]
        }`
        os.Setenv("VCAP_SERVICES", vcapJSON)
        defer os.Unsetenv("VCAP_SERVICES")
        
        ctx := createTestContext(t)
        framework := frameworks.NewMyNewFramework(ctx)
        
        name, err := framework.Detect()
        if err != nil {
            t.Fatalf("Unexpected error: %v", err)
        }
        
        if name != "my-new-framework" {
            t.Errorf("Expected 'my-new-framework', got: %s", name)
        }
    })
    
    t.Run("without service", func(t *testing.T) {
        os.Unsetenv("VCAP_SERVICES")
        
        ctx := createTestContext(t)
        framework := frameworks.NewMyNewFramework(ctx)
        
        name, err := framework.Detect()
        if err != nil {
            t.Fatalf("Unexpected error: %v", err)
        }
        
        if name != "" {
            t.Errorf("Expected no detection, got: %s", name)
        }
    })
}

func TestMyNewFrameworkSupply(t *testing.T) {
    // Test supply phase
}

func TestMyNewFrameworkFinalize(t *testing.T) {
    // Test finalize phase
}

func createTestContext(t *testing.T) *frameworks.Context {
    tmpDir, err := os.MkdirTemp("", "test-*")
    if err != nil {
        t.Fatalf("Failed to create temp dir: %v", err)
    }
    
    t.Cleanup(func() {
        os.RemoveAll(tmpDir)
    })
    
    logger := libbuildpack.NewLogger(os.Stdout)
    stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, &libbuildpack.Manifest{})
    
    return &frameworks.Context{
        Stager: stager,
        Log:    logger,
    }
}
```

## Best Practices

### 1. Test One Thing at a Time

```go
// GOOD - Tests one specific behavior
func TestDetectWithValidService(t *testing.T) {
    // Setup valid service
    // Test detection succeeds
}

func TestDetectWithInvalidService(t *testing.T) {
    // Setup invalid service
    // Test detection fails
}

// BAD - Tests multiple things
func TestDetect(t *testing.T) {
    // Test with valid service
    // Test with invalid service
    // Test with no service
    // Test with multiple services
    // ...
}
```

### 2. Use Descriptive Test Names

```go
// GOOD
func TestDetect_WithNewRelicService_ReturnsNewRelicAgent(t *testing.T)
func TestSupply_WhenDependencyMissing_ReturnsError(t *testing.T)

// BAD
func TestDetect1(t *testing.T)
func TestDetect2(t *testing.T)
```

### 3. Clean Up Resources

```go
// GOOD - Use t.Cleanup for automatic cleanup
func TestMyFunction(t *testing.T) {
    tmpDir, _ := os.MkdirTemp("", "test-*")
    t.Cleanup(func() {
        os.RemoveAll(tmpDir)
    })
    
    // Test logic
}

// GOOD - Use defer for immediate cleanup
func TestMyFunction(t *testing.T) {
    tmpDir, _ := os.MkdirTemp("", "test-*")
    defer os.RemoveAll(tmpDir)
    
    // Test logic
}
```

### 4. Test Error Messages

```go
func TestErrorMessage(t *testing.T) {
    err := MyFunction()
    
    if err == nil {
        t.Fatal("Expected error, got nil")
    }
    
    // Verify error is helpful
    if !strings.Contains(err.Error(), "required field missing") {
        t.Errorf("Error message not helpful: %v", err)
    }
}
```

### 5. Avoid Hardcoded Paths

```go
// BAD
testFile := "/tmp/test/file.txt"

// GOOD
tmpDir, _ := os.MkdirTemp("", "test-*")
testFile := filepath.Join(tmpDir, "file.txt")
```

### 6. Use Helper Functions

```go
func createFrameworkContext(t *testing.T, buildDir string) *frameworks.Context {
    logger := libbuildpack.NewLogger(os.Stdout)
    stager := libbuildpack.NewStager([]string{buildDir, "", "0"}, logger, &libbuildpack.Manifest{})
    
    return &frameworks.Context{
        Stager: stager,
        Log:    logger,
    }
}

func setVCAPServices(t *testing.T, json string) {
    os.Setenv("VCAP_SERVICES", json)
    t.Cleanup(func() {
        os.Unsetenv("VCAP_SERVICES")
    })
}
```

### 7. Test Parallel-Safe

Ensure tests can run in parallel:

```go
func TestParallelSafe(t *testing.T) {
    t.Parallel() // Mark test as parallel-safe
    
    // Use unique temp directories
    tmpDir, _ := os.MkdirTemp("", "test-*")
    defer os.RemoveAll(tmpDir)
    
    // Avoid shared state
    // Use t.Cleanup for cleanup
}
```

## Troubleshooting

### Tests Failing After Code Changes

1. **Rebuild binaries:**
   ```bash
   ./scripts/build.sh
   ```

2. **Clear stale test cache:**
   ```bash
   go clean -testcache
   ```

3. **Run with verbose output:**
   ```bash
   cd src/java
   ginkgo -v frameworks/
   ```

### Integration Tests Timing Out

1. **Increase timeout:**
   ```bash
   # In test code
   SetDefaultEventuallyTimeout(60 * time.Second)
   ```

2. **Run serially:**
   ```bash
   ./scripts/integration.sh --platform docker --parallel false
   ```

3. **Check Docker resources:**
   - Increase Docker memory/CPU limits
   - Check for running containers: `docker ps`

### Test Fixtures Not Found

```bash
# Verify fixtures exist
ls src/integration/testdata/

# Check paths in test code
# Use filepath.Join with relative paths
```

### Ginkgo Not Found

```bash
# Install Ginkgo
go install github.com/onsi/ginkgo/v2/ginkgo@latest

# Add to PATH
export PATH="${PATH}:${HOME}/go/bin"
```

### Permission Errors

```bash
# Ensure test directories are writable
chmod -R 755 /tmp/test-*

# Check temp directory location
echo $TMPDIR
```

### Flaky Tests

1. **Identify flaky test:**
   ```bash
   # Run multiple times
   for i in {1..10}; do go test ./frameworks/...; done
   ```

2. **Common causes:**
   - Race conditions (use `go test -race`)
   - Filesystem timing issues (add small delays)
   - Shared state between tests
   - Network dependencies

3. **Fix strategies:**
   - Use `t.Parallel()` to isolate tests
   - Use unique temp directories per test
   - Add retries for network operations
   - Mock external dependencies

## Next Steps

- **[Implementing Frameworks](IMPLEMENTING_FRAMEWORKS.md)** - Learn framework patterns to test
- **[Implementing Containers](IMPLEMENTING_CONTAINERS.md)** - Learn container patterns to test
- **[Developer Guide](DEVELOPING.md)** - Development workflow and tools
- **[Contributing](../CONTRIBUTING.md)** - Code standards and conventions
- **[Architecture](../ARCHITECTURE.md)** - Understand system design for better tests

## Resources

- [Ginkgo Documentation](https://onsi.github.io/ginkgo/)
- [Gomega Matchers](https://onsi.github.io/gomega/)
- [Go Testing Package](https://golang.org/pkg/testing/)
- [Switchblade Framework](https://github.com/cloudfoundry/switchblade)
- [Cloud Foundry Testing Best Practices](https://docs.cloudfoundry.org/buildpacks/developing-buildpacks.html)
