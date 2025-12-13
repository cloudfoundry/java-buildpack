# Implementing Frameworks

This guide explains how to implement new framework support in the Cloud Foundry Java Buildpack. Frameworks provide additional capabilities to Java applications, such as APM agents, security providers, profilers, and runtime enhancements.

## Table of Contents

- [Overview](#overview)
- [Framework Interface](#framework-interface)
- [Framework Types](#framework-types)
- [Implementation Steps](#implementation-steps)
- [Complete Examples](#complete-examples)
- [Common Patterns](#common-patterns)
- [Testing Frameworks](#testing-frameworks)
- [Configuration](#configuration)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

### What is a Framework?

A framework is a buildpack component that adds functionality to Java applications at runtime. Examples include:

- **APM Agents**: New Relic, AppDynamics, Dynatrace, DataDog
- **Security Providers**: Luna HSM, Seeker IAST, Container Security Provider
- **Profilers**: JProfiler, YourKit
- **Debugging Tools**: Java Debug Wire Protocol (JDWP)
- **Database Drivers**: PostgreSQL JDBC, MariaDB JDBC
- **Utilities**: JMX, Java Options, Logging configuration

### Framework Lifecycle

Frameworks participate in three phases of the buildpack lifecycle:

1. **Detect Phase** - Determine if the framework should be included
2. **Supply Phase** - Download and install framework dependencies (during staging)
3. **Finalize Phase** - Configure the framework for runtime (write environment variables, profile.d scripts)

### Files Required

To implement a new framework, you need:

1. **Implementation**: `src/java/frameworks/my_framework.go`
2. **Tests**: `src/java/frameworks/my_framework_test.go`
3. **Configuration**: `config/my_framework.yml`
4. **Documentation**: `docs/framework-my_framework.md`
5. **Registration**: Add to `config/components.yml`

## Framework Interface

All frameworks must implement this interface:

```go
// src/java/frameworks/framework.go
type Framework interface {
    Detect() (string, error)  // Returns detection tag if included, empty string if not
    Supply() error            // Install dependencies during staging
    Finalize() error          // Configure for runtime
}
```

### Context Structure

Frameworks receive a `Context` struct with access to buildpack services:

```go
type Context struct {
    Stager    *libbuildpack.Stager     // Build directory, deps directory access
    Manifest  *libbuildpack.Manifest   // Buildpack manifest with dependency versions
    Installer *libbuildpack.Installer  // Download and install dependencies
    Log       *libbuildpack.Logger     // Logging
    Command   *libbuildpack.Command    // Execute shell commands
}
```

**Key Context Methods:**

```go
// Get build directory (staging directory during supply, /home/vcap/app at runtime)
buildDir := ctx.Stager.BuildDir()

// Get deps directory (where framework dependencies are installed)
depsDir := ctx.Stager.DepDir()

// Write environment variable to .profile.d/
ctx.Stager.WriteEnvFile("MY_VAR", "value")

// Write profile.d script (executed before app starts)
ctx.Stager.WriteProfileD("my_framework.sh", "export MY_VAR=value")

// Log messages
ctx.Log.BeginStep("Installing My Framework")
ctx.Log.Info("Installed version %s", version)
ctx.Log.Warning("Optional feature not available")
ctx.Log.Debug("Debug information")

// Get dependency version from manifest
dep, err := ctx.Manifest.DefaultVersion("my-framework")

// Install dependency
err := ctx.Installer.InstallDependency(dep, targetDir)
```

## Framework Types

### Type 1: Service-Bound Frameworks

Detect when a specific Cloud Foundry service is bound via `VCAP_SERVICES`.

**Examples:** New Relic, AppDynamics, Seeker Security Provider

**Detection:** Looks for service name/label/tags in `VCAP_SERVICES`

### Type 2: Configuration-Based Frameworks

Enable/disable via environment variable or configuration.

**Examples:** Debug, JMX, Java Memory Assistant

**Detection:** Checks `JBP_CONFIG_*` or `BPL_*` environment variables

### Type 3: File-Based Detection

Detect based on files present in the application.

**Examples:** Container Customizer (detects Spring Boot WARs)

**Detection:** Checks for specific files/directories in build directory

### Type 4: Passive Frameworks

Always available or conditionally enabled by configuration.

**Examples:** PostgreSQL JDBC, Java Options

**Detection:** Usually enabled if configuration allows

## Implementation Steps

### Step 1: Create Framework Structure

Create `src/java/frameworks/my_framework.go`:

```go
package frameworks

import (
    "fmt"
    "os"
    "path/filepath"
)

// MyFramework implements ...
type MyFramework struct {
    context *Context
}

// NewMyFramework creates a new instance
func NewMyFramework(ctx *Context) *MyFramework {
    return &MyFramework{context: ctx}
}

// Detect checks if framework should be included
func (m *MyFramework) Detect() (string, error) {
    // TODO: Implement detection logic
    return "", nil
}

// Supply installs framework dependencies
func (m *MyFramework) Supply() error {
    // TODO: Implement supply phase
    return nil
}

// Finalize configures framework for runtime
func (m *MyFramework) Finalize() error {
    // TODO: Implement finalize phase
    return nil
}
```

### Step 2: Implement Detection Logic

Choose the appropriate detection pattern based on your framework type:

**Service-Bound Detection:**
```go
func (m *MyFramework) Detect() (string, error) {
    vcapServices, err := GetVCAPServices()
    if err != nil {
        return "", nil
    }
    
    if !vcapServices.HasService("my-service") {
        return "", nil
    }
    
    // Verify required credentials
    service := vcapServices.GetService("my-service")
    if service == nil {
        return "", nil
    }
    
    apiKey, ok := service.Credentials["api_key"].(string)
    if !ok || apiKey == "" {
        return "", nil
    }
    
    return "my-framework", nil
}
```

**Configuration-Based Detection:**
```go
func (m *MyFramework) Detect() (string, error) {
    enabled := os.Getenv("JBP_CONFIG_MY_FRAMEWORK")
    if enabled == "" {
        return "", nil // Not configured
    }
    
    // Parse config to check enabled flag
    if contains(enabled, "enabled: true") {
        return "my-framework", nil
    }
    
    return "", nil
}
```

**File-Based Detection:**
```go
func (m *MyFramework) Detect() (string, error) {
    buildDir := m.context.Stager.BuildDir()
    markerFile := filepath.Join(buildDir, "META-INF", "my-marker.xml")
    
    if _, err := os.Stat(markerFile); err == nil {
        return "my-framework", nil
    }
    
    return "", nil
}
```

### Step 3: Implement Supply Phase

Download and install framework dependencies:

```go
func (m *MyFramework) Supply() error {
    m.context.Log.BeginStep("Installing My Framework")
    
    // Get version from manifest
    dep, err := m.context.Manifest.DefaultVersion("my-framework")
    if err != nil {
        return fmt.Errorf("unable to determine version: %w", err)
    }
    
    // Create target directory in deps
    targetDir := filepath.Join(m.context.Stager.DepDir(), "my_framework")
    if err := os.MkdirAll(targetDir, 0755); err != nil {
        return fmt.Errorf("failed to create directory: %w", err)
    }
    
    // Download and extract dependency
    if err := m.context.Installer.InstallDependency(dep, targetDir); err != nil {
        return fmt.Errorf("failed to install: %w", err)
    }
    
    m.context.Log.Info("Installed My Framework version %s", dep.Version)
    return nil
}
```

### Step 4: Implement Finalize Phase

Configure the framework for runtime execution:

```go
func (m *MyFramework) Finalize() error {
    // Find installed agent JAR
    frameworkDir := filepath.Join(m.context.Stager.DepDir(), "my_framework")
    jarPath := filepath.Join(frameworkDir, "my-agent.jar")
    
    // Write profile.d script to configure at runtime
    profileScript := fmt.Sprintf(`#!/bin/bash
# My Framework Configuration
export MY_FRAMEWORK_HOME="$DEPS_DIR/0/my_framework"
export JAVA_OPTS="${JAVA_OPTS} -javaagent:%s"
`, jarPath)
    
    if err := m.context.Stager.WriteProfileD("my_framework.sh", profileScript); err != nil {
        return fmt.Errorf("failed to write profile.d script: %w", err)
    }
    
    m.context.Log.Info("Configured My Framework")
    return nil
}
```

### Step 5: Register Framework

Add to `config/components.yml`:

```yaml
frameworks:
  - "JavaBuildpack::Framework::AppDynamicsAgent"
  - "JavaBuildpack::Framework::MyFramework"  # Add your framework
  - "JavaBuildpack::Framework::NewRelicAgent"
```

**Note**: The component names still use Ruby-style class names for compatibility. The Go implementation maps these to the corresponding Go constructors.

### Step 6: Create Configuration File

Create `config/my_framework.yml`:

```yaml
# Cloud Foundry Java Buildpack config for My Framework
---
enabled: true
version: 1.+
repository_root: "{default.repository.root}/my-framework"
```

### Step 7: Add Tests

Create `src/java/frameworks/my_framework_test.go`:

```go
package frameworks_test

import (
    "os"
    "testing"
    "github.com/cloudfoundry/java-buildpack/src/java/frameworks"
    "github.com/cloudfoundry/libbuildpack"
)

func TestMyFrameworkDetect(t *testing.T) {
    tmpDir, _ := os.MkdirTemp("", "test-*")
    defer os.RemoveAll(tmpDir)
    
    logger := libbuildpack.NewLogger(os.Stdout)
    stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, &libbuildpack.Manifest{})
    
    ctx := &frameworks.Context{
        Stager: stager,
        Log:    logger,
    }
    
    framework := frameworks.NewMyFramework(ctx)
    
    // Test without service
    name, err := framework.Detect()
    if err != nil {
        t.Fatalf("Unexpected error: %v", err)
    }
    if name != "" {
        t.Errorf("Expected no detection, got: %s", name)
    }
    
    // Test with service
    vcapJSON := `{
        "my-service": [{
            "name": "my-service-instance",
            "credentials": {"api_key": "test-key"}
        }]
    }`
    os.Setenv("VCAP_SERVICES", vcapJSON)
    defer os.Unsetenv("VCAP_SERVICES")
    
    name, err = framework.Detect()
    if err != nil {
        t.Fatalf("Unexpected error: %v", err)
    }
    if name != "my-framework" {
        t.Errorf("Expected 'my-framework', got: %s", name)
    }
}
```

### Step 8: Write Documentation

Create `docs/framework-my_framework.md` with usage instructions, configuration options, and examples.

## Complete Examples

### Example 1: Simple Configuration-Based Framework (Debug)

The Debug framework is the simplest example - it enables Java debugging based on configuration.

**File**: `src/java/frameworks/debug.go:1`

```go
package frameworks

import (
    "fmt"
    "os"
    "strconv"
)

type DebugFramework struct {
    context *Context
}

func NewDebugFramework(ctx *Context) *DebugFramework {
    return &DebugFramework{context: ctx}
}

// Detect: Check if debug is enabled in configuration
func (d *DebugFramework) Detect() (string, error) {
    if !d.isEnabled() {
        return "", nil
    }
    port := d.getPort()
    return fmt.Sprintf("debug=%d", port), nil
}

// Supply: Log that debugging will be enabled
func (d *DebugFramework) Supply() error {
    if !d.isEnabled() {
        return nil
    }
    
    port := d.getPort()
    suspend := d.getSuspend()
    
    suspendMsg := ""
    if suspend {
        suspendMsg = ", suspended on start"
    }
    
    d.context.Log.BeginStep("Debugging enabled on port %d%s", port, suspendMsg)
    return nil
}

// Finalize: Add JDWP agent options to JAVA_OPTS
func (d *DebugFramework) Finalize() error {
    if !d.isEnabled() {
        return nil
    }
    
    port := d.getPort()
    suspend := d.getSuspend()
    
    suspendValue := "n"
    if suspend {
        suspendValue = "y"
    }
    
    debugOpts := fmt.Sprintf(
        "-agentlib:jdwp=transport=dt_socket,server=y,address=%d,suspend=%s",
        port, suspendValue,
    )
    
    // Add to JAVA_OPTS
    javaOpts := os.Getenv("JAVA_OPTS")
    if javaOpts != "" {
        javaOpts += " "
    }
    javaOpts += debugOpts
    
    if err := d.context.Stager.WriteEnvFile("JAVA_OPTS", javaOpts); err != nil {
        return fmt.Errorf("failed to set JAVA_OPTS: %w", err)
    }
    
    return nil
}

// Helper: Check if debugging is enabled
func (d *DebugFramework) isEnabled() bool {
    // Check BPL_DEBUG_ENABLED (Cloud Native Buildpacks convention)
    bplEnabled := os.Getenv("BPL_DEBUG_ENABLED")
    if bplEnabled == "true" || bplEnabled == "1" {
        return true
    }
    
    // Check JBP_CONFIG_DEBUG (Java Buildpack convention)
    config := os.Getenv("JBP_CONFIG_DEBUG")
    if contains(config, "enabled: true") {
        return true
    }
    
    return false
}

// Helper: Get debug port (default 8000)
func (d *DebugFramework) getPort() int {
    if port := os.Getenv("BPL_DEBUG_PORT"); port != "" {
        if p, err := strconv.Atoi(port); err == nil && p > 0 {
            return p
        }
    }
    return 8000
}

// Helper: Check if JVM should suspend on start
func (d *DebugFramework) getSuspend() bool {
    config := os.Getenv("JBP_CONFIG_DEBUG")
    return contains(config, "suspend: true")
}
```

**Key Points:**
- ✅ Simple configuration-based detection
- ✅ No dependencies to download (Supply does minimal work)
- ✅ Finalize adds JVM options to enable debugging
- ✅ Respects multiple configuration conventions (BPL_*, JBP_CONFIG_*)

---

### Example 2: File-Based Detection (Container Customizer)

The Container Customizer detects Spring Boot WAR applications and adds Tomcat customization support.

**File**: `src/java/frameworks/container_customizer.go:1`

```go
package frameworks

import (
    "fmt"
    "os"
    "path/filepath"
)

type ContainerCustomizerFramework struct {
    context *Context
}

func NewContainerCustomizerFramework(ctx *Context) *ContainerCustomizerFramework {
    return &ContainerCustomizerFramework{context: ctx}
}

// Detect: Check for Spring Boot WAR structure
func (c *ContainerCustomizerFramework) Detect() (string, error) {
    buildDir := c.context.Stager.BuildDir()
    
    // Spring Boot WARs have both WEB-INF and BOOT-INF directories
    webInfPath := filepath.Join(buildDir, "WEB-INF")
    bootInfPath := filepath.Join(buildDir, "BOOT-INF")
    
    webInfStat, webInfErr := os.Stat(webInfPath)
    bootInfStat, bootInfErr := os.Stat(bootInfPath)
    
    if webInfErr == nil && webInfStat.IsDir() &&
       bootInfErr == nil && bootInfStat.IsDir() {
        
        // Verify it's actually Spring Boot
        if c.hasSpringBootJars(buildDir) {
            return "Container Customizer", nil
        }
    }
    
    return "", nil
}

// Helper: Check for spring-boot-*.jar files
func (c *ContainerCustomizerFramework) hasSpringBootJars(buildDir string) bool {
    libDirs := []string{
        filepath.Join(buildDir, "WEB-INF", "lib"),
        filepath.Join(buildDir, "BOOT-INF", "lib"),
    }
    
    for _, libDir := range libDirs {
        entries, err := os.ReadDir(libDir)
        if err != nil {
            continue
        }
        
        for _, entry := range entries {
            if filepath.Ext(entry.Name()) == ".jar" && 
               strings.Contains(entry.Name(), "spring-boot-") {
                return true
            }
        }
    }
    return false
}

// Supply: Download Container Customizer JAR
func (c *ContainerCustomizerFramework) Supply() error {
    c.context.Log.BeginStep("Installing Container Customizer")
    
    // Get version from manifest
    dep, err := c.context.Manifest.DefaultVersion("container-customizer")
    if err != nil {
        return fmt.Errorf("unable to determine version: %w", err)
    }
    
    // Install to deps directory
    customizerDir := filepath.Join(c.context.Stager.DepDir(), "container_customizer")
    if err := c.context.Installer.InstallDependency(dep, customizerDir); err != nil {
        return fmt.Errorf("failed to install: %w", err)
    }
    
    c.context.Log.Info("Installed Container Customizer version %s", dep.Version)
    return nil
}

// Finalize: Add Container Customizer JAR to classpath
func (c *ContainerCustomizerFramework) Finalize() error {
    // Find installed JAR
    customizerDir := filepath.Join(c.context.Stager.DepDir(), "container_customizer")
    jarPattern := filepath.Join(customizerDir, "container-customizer-*.jar")
    
    matches, err := filepath.Glob(jarPattern)
    if err != nil || len(matches) == 0 {
        c.context.Log.Warning("Container Customizer JAR not found")
        return nil
    }
    
    // Create runtime path (using $DEPS_DIR variable)
    relPath := filepath.Base(matches[0])
    runtimePath := fmt.Sprintf("$DEPS_DIR/0/container_customizer/%s", relPath)
    
    // Write profile.d script to add to classpath
    profileScript := fmt.Sprintf(`# Container Customizer Framework
export CLASSPATH="%s:${CLASSPATH:-}"
`, runtimePath)
    
    if err := c.context.Stager.WriteProfileD("container_customizer.sh", profileScript); err != nil {
        return fmt.Errorf("failed to write profile.d script: %w", err)
    }
    
    c.context.Log.Info("Configured Container Customizer for embedded Tomcat")
    return nil
}
```

**Key Points:**
- ✅ File-based detection (checks for WEB-INF and BOOT-INF)
- ✅ Downloads dependency JAR during Supply
- ✅ Adds JAR to classpath via profile.d script
- ✅ Uses `$DEPS_DIR` variable for runtime paths

---

### Example 3: Service-Bound Framework (Seeker Security Provider)

The Seeker Security Provider detects a bound Seeker service and downloads the agent.

**File**: `src/java/frameworks/seeker_security_provider.go:1`

```go
package frameworks

import (
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "strings"
)

type SeekerSecurityProviderFramework struct {
    context *Context
}

func NewSeekerSecurityProviderFramework(ctx *Context) *SeekerSecurityProviderFramework {
    return &SeekerSecurityProviderFramework{context: ctx}
}

// Detect: Check for bound Seeker service
func (s *SeekerSecurityProviderFramework) Detect() (string, error) {
    seekerService, err := s.findSeekerService()
    if err != nil {
        return "", nil
    }
    
    // Verify required credentials
    credentials, ok := seekerService["credentials"].(map[string]interface{})
    if !ok {
        return "", nil
    }
    
    serverURL, ok := credentials["seeker_server_url"].(string)
    if !ok || serverURL == "" {
        return "", nil
    }
    
    return "seeker-security-provider", nil
}

// Supply: Download Seeker agent from server
func (s *SeekerSecurityProviderFramework) Supply() error {
    s.context.Log.BeginStep("Installing Synopsys Seeker Security Provider")
    
    seekerService, err := s.findSeekerService()
    if err != nil {
        return fmt.Errorf("Seeker service not found: %w", err)
    }
    
    credentials, ok := seekerService["credentials"].(map[string]interface{})
    if !ok {
        return fmt.Errorf("credentials not found")
    }
    
    serverURL, ok := credentials["seeker_server_url"].(string)
    if !ok {
        return fmt.Errorf("seeker_server_url not found")
    }
    
    // Download agent from Seeker server
    // Agent URL: {serverURL}/rest/api/latest/installers/agents/binaries/JAVA
    
    seekerDir := filepath.Join(s.context.Stager.DepDir(), "seeker_security_provider")
    if err := os.MkdirAll(seekerDir, 0755); err != nil {
        return fmt.Errorf("failed to create directory: %w", err)
    }
    
    // Download and extract agent ZIP
    // (Implementation would use http.Get and archive/zip)
    
    s.context.Log.Info("Installed Synopsys Seeker from %s", serverURL)
    return nil
}

// Finalize: Configure Seeker agent
func (s *SeekerSecurityProviderFramework) Finalize() error {
    seekerService, err := s.findSeekerService()
    if err != nil {
        return err
    }
    
    credentials := seekerService["credentials"].(map[string]interface{})
    serverURL := credentials["seeker_server_url"].(string)
    
    // Find agent JAR
    seekerDir := filepath.Join(s.context.Stager.DepDir(), "seeker_security_provider")
    agentJar := filepath.Join(seekerDir, "seeker-agent.jar")
    
    // Write profile.d script
    profileScript := fmt.Sprintf(`#!/bin/bash
# Synopsys Seeker Security Provider
export SEEKER_SERVER_URL="%s"
export JAVA_OPTS="${JAVA_OPTS} -javaagent:%s"
`, serverURL, agentJar)
    
    if err := s.context.Stager.WriteProfileD("seeker_security_provider.sh", profileScript); err != nil {
        return fmt.Errorf("failed to write profile.d script: %w", err)
    }
    
    s.context.Log.Info("Configured Synopsys Seeker Security Provider")
    return nil
}

// Helper: Find Seeker service in VCAP_SERVICES
func (s *SeekerSecurityProviderFramework) findSeekerService() (map[string]interface{}, error) {
    vcapServices := os.Getenv("VCAP_SERVICES")
    if vcapServices == "" {
        return nil, fmt.Errorf("VCAP_SERVICES not set")
    }
    
    var services map[string][]map[string]interface{}
    if err := json.Unmarshal([]byte(vcapServices), &services); err != nil {
        return nil, err
    }
    
    // Search for service with "seeker" in name/label/tags
    for serviceType, serviceList := range services {
        if strings.Contains(strings.ToLower(serviceType), "seeker") {
            if len(serviceList) > 0 {
                return serviceList[0], nil
            }
        }
        
        for _, service := range serviceList {
            // Check service name
            if name, ok := service["name"].(string); ok {
                if strings.Contains(strings.ToLower(name), "seeker") {
                    return service, nil
                }
            }
            
            // Check tags
            if tags, ok := service["tags"].([]interface{}); ok {
                for _, tag := range tags {
                    if tagStr, ok := tag.(string); ok {
                        if strings.Contains(strings.ToLower(tagStr), "seeker") {
                            return service, nil
                        }
                    }
                }
            }
        }
    }
    
    return nil, fmt.Errorf("Seeker service not found")
}
```

**Key Points:**
- ✅ Service-bound detection (parses VCAP_SERVICES)
- ✅ Flexible service matching (name, label, or tags)
- ✅ Downloads agent from service-provided URL
- ✅ Configures agent with service credentials
- ✅ Adds javaagent to JAVA_OPTS

## Common Patterns

### Pattern 1: Adding a Java Agent

Many frameworks add a `-javaagent` option. Use this pattern:

```go
func (f *MyFramework) Finalize() error {
    agentPath := filepath.Join(f.context.Stager.DepDir(), "my_framework", "agent.jar")
    
    javaOpts := os.Getenv("JAVA_OPTS")
    if javaOpts != "" {
        javaOpts += " "
    }
    javaOpts += fmt.Sprintf("-javaagent:%s", agentPath)
    
    return f.context.Stager.WriteEnvFile("JAVA_OPTS", javaOpts)
}
```

### Pattern 2: Parsing VCAP_SERVICES

To find a bound service:

```go
func (f *MyFramework) findService() (*VCAPService, error) {
    vcapServices, err := GetVCAPServices()
    if err != nil {
        return nil, err
    }
    
    // Check by service type
    if vcapServices.HasService("my-service") {
        return vcapServices.GetService("my-service"), nil
    }
    
    // Check by tag
    if vcapServices.HasTag("my-tag") {
        return vcapServices.GetServiceByTag("my-tag"), nil
    }
    
    return nil, fmt.Errorf("service not found")
}
```

### Pattern 3: Writing Profile.d Scripts

Profile.d scripts run before the application starts:

```go
func (f *MyFramework) Finalize() error {
    script := `#!/bin/bash
# My Framework Configuration

# Set environment variables
export MY_VAR="value"

# Add to JAVA_OPTS
export JAVA_OPTS="${JAVA_OPTS} -Dmy.property=value"

# Add to classpath
export CLASSPATH="$DEPS_DIR/0/my_framework/lib/*:${CLASSPATH}"
`
    
    return f.context.Stager.WriteProfileD("my_framework.sh", script)
}
```

### Pattern 4: Conditional Enabling

Allow users to disable via configuration:

```go
func (f *MyFramework) isEnabled() bool {
    // Check explicit enable/disable
    config := os.Getenv("JBP_CONFIG_MY_FRAMEWORK")
    
    if contains(config, "enabled: false") {
        return false
    }
    
    if contains(config, "enabled: true") {
        return true
    }
    
    // Check if service is bound (auto-enable)
    vcapServices, _ := GetVCAPServices()
    return vcapServices.HasService("my-service")
}
```

### Pattern 5: Downloading External Files

Download files from URLs in service credentials:

```go
func (f *MyFramework) Supply() error {
    service := f.getService()
    downloadURL := service.Credentials["download_url"].(string)
    
    targetDir := filepath.Join(f.context.Stager.DepDir(), "my_framework")
    os.MkdirAll(targetDir, 0755)
    
    // Use installer to download
    // (Implementation would use http.Get or libbuildpack downloader)
    
    return nil
}
```

### Pattern 6: Runtime vs. Staging Paths

Convert staging paths to runtime paths using environment variables:

```go
// During Finalize, use runtime path variables
stagingPath := "/tmp/staging/deps/0/my_framework/lib.jar"
runtimePath := "$DEPS_DIR/0/my_framework/lib.jar"

// Use runtimePath in profile.d scripts
profileScript := fmt.Sprintf("export CLASSPATH=%s:$CLASSPATH", runtimePath)
```

## Testing Frameworks

### Basic Test Structure

```go
package frameworks_test

import (
    "os"
    "testing"
    "github.com/cloudfoundry/java-buildpack/src/java/frameworks"
    "github.com/cloudfoundry/libbuildpack"
)

func TestMyFrameworkDetect(t *testing.T) {
    // Create temp directory for testing
    tmpDir, err := os.MkdirTemp("", "test-*")
    if err != nil {
        t.Fatalf("Failed to create temp dir: %v", err)
    }
    defer os.RemoveAll(tmpDir)
    
    // Create test context
    logger := libbuildpack.NewLogger(os.Stdout)
    stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, &libbuildpack.Manifest{})
    
    ctx := &frameworks.Context{
        Stager: stager,
        Log:    logger,
    }
    
    framework := frameworks.NewMyFramework(ctx)
    
    // Test detection
    name, err := framework.Detect()
    if err != nil {
        t.Fatalf("Unexpected error: %v", err)
    }
    
    if name != "my-framework" {
        t.Errorf("Expected 'my-framework', got: %s", name)
    }
}
```

### Testing with VCAP_SERVICES

```go
func TestServiceBoundFramework(t *testing.T) {
    vcapJSON := `{
        "my-service": [{
            "name": "my-service-instance",
            "label": "my-service",
            "credentials": {
                "api_key": "test-key-123"
            }
        }]
    }`
    
    os.Setenv("VCAP_SERVICES", vcapJSON)
    defer os.Unsetenv("VCAP_SERVICES")
    
    // Test framework detection
    // ...
}
```

### Testing File Detection

```go
func TestFileBasedDetection(t *testing.T) {
    tmpDir, _ := os.MkdirTemp("", "test-*")
    defer os.RemoveAll(tmpDir)
    
    // Create marker file
    markerFile := filepath.Join(tmpDir, "META-INF", "marker.xml")
    os.MkdirAll(filepath.Dir(markerFile), 0755)
    os.WriteFile(markerFile, []byte("<marker/>"), 0644)
    
    // Test framework detection
    // ...
}
```

### Running Tests

```bash
# Run all framework tests
cd src/java
ginkgo frameworks/

# Run specific test
ginkgo frameworks/my_framework_test.go

# Run with verbose output
ginkgo -v frameworks/

# Watch and re-run on changes
ginkgo watch frameworks/
```

## Configuration

### Configuration File Format

`config/my_framework.yml`:

```yaml
# Cloud Foundry Java Buildpack config for My Framework
---
# Enable/disable framework (default: true)
enabled: true

# Version to install (supports version ranges)
version: 1.+

# Repository location for downloading artifacts
repository_root: "{default.repository.root}/my-framework"

# Framework-specific options
options:
  debug: false
  timeout: 30
```

### Version Ranges

The buildpack supports semantic version ranges:

- `1.+` - Latest 1.x version
- `1.2.+` - Latest 1.2.x version
- `1.2.3` - Exact version
- `[1.2.0,2.0.0)` - Range from 1.2.0 to 2.0.0 (exclusive)

### Environment Variable Overrides

Users can override configuration via environment variables:

```bash
# Override entire config file
cf set-env my-app JBP_CONFIG_MY_FRAMEWORK '{ enabled: true, version: 2.0.0 }'

# Specific property
cf set-env my-app JBP_CONFIG_MY_FRAMEWORK '{ options: { debug: true } }'
```

## Best Practices

### 1. Error Handling

Always return meaningful errors with context:

```go
// BAD
if err != nil {
    return err
}

// GOOD
if err != nil {
    return fmt.Errorf("failed to install My Framework: %w", err)
}
```

### 2. Logging

Use appropriate log levels:

```go
ctx.Log.BeginStep("Installing My Framework")      // Major steps
ctx.Log.Info("Installed version %s", version)     // Important info
ctx.Log.Warning("Optional feature disabled")      // Warnings
ctx.Log.Debug("Config value: %+v", config)        // Debug details
```

### 3. Graceful Degradation

Don't fail if optional features are unavailable:

```go
dep, err := ctx.Manifest.DefaultVersion("optional-component")
if err != nil {
    ctx.Log.Warning("Optional component not available, skipping")
    return nil  // Continue without failing
}
```

### 4. Clean Detection

Detection should be fast and have no side effects:

```go
// BAD - Don't download or modify files in Detect
func (f *MyFramework) Detect() (string, error) {
    ctx.Installer.InstallDependency(...)  // NO!
    return "my-framework", nil
}

// GOOD - Only check conditions
func (f *MyFramework) Detect() (string, error) {
    if !f.isServiceBound() {
        return "", nil
    }
    return "my-framework", nil
}
```

### 5. Idempotency

Supply and Finalize should be idempotent (safe to run multiple times):

```go
func (f *MyFramework) Supply() error {
    targetDir := filepath.Join(ctx.Stager.DepDir(), "my_framework")
    
    // Check if already installed
    if _, err := os.Stat(filepath.Join(targetDir, "agent.jar")); err == nil {
        ctx.Log.Debug("Already installed, skipping")
        return nil
    }
    
    // Install...
}
```

### 6. Path Handling

Always use `filepath.Join` for cross-platform compatibility:

```go
// BAD
path := ctx.Stager.DepDir() + "/my_framework/agent.jar"

// GOOD
path := filepath.Join(ctx.Stager.DepDir(), "my_framework", "agent.jar")
```

### 7. Security

Never log sensitive information (API keys, passwords, tokens):

```go
// BAD
ctx.Log.Info("API Key: %s", apiKey)

// GOOD
ctx.Log.Info("API Key configured")
```

## Troubleshooting

### Framework Not Detected

**Check:**
1. Is the service bound? `cf services`
2. Is VCAP_SERVICES set? `cf env my-app`
3. Is detection logic correct? Add debug logging
4. Is framework registered in `config/components.yml`?

### Supply Phase Fails

**Check:**
1. Is dependency in buildpack manifest?
2. Is download URL accessible?
3. Are permissions correct (0755 for directories)?
4. Check logs: `cf logs my-app --recent`

### Finalize Phase Issues

**Check:**
1. Are paths using `$DEPS_DIR` variable (not hardcoded)?
2. Are profile.d scripts executable?
3. Are JAR files actually installed during Supply?
4. Test profile.d scripts: `cf ssh my-app` then `cat .profile.d/my_framework.sh`

### Runtime Issues

**Check:**
1. View environment: `cf ssh my-app` then `env`
2. Check JAVA_OPTS: `cf ssh my-app` then `echo $JAVA_OPTS`
3. Verify files exist: `cf ssh my-app` then `ls $DEPS_DIR/0/my_framework/`
4. Check application logs: `cf logs my-app`

### Testing Issues

```bash
# Rebuild before testing
./scripts/build.sh

# Run tests with verbose output
cd src/java
ginkgo -v frameworks/my_framework_test.go

# Check for Go errors
go vet ./frameworks/...
gofmt -d frameworks/
```

## Next Steps

- **[Testing Guide](TESTING.md)** - Comprehensive testing patterns and strategies
- **[Implementing Containers](IMPLEMENTING_CONTAINERS.md)** - Learn how to add new container types
- **[Implementing JREs](IMPLEMENTING_JRES.md)** - Learn how to add new JRE providers
- **[Architecture Overview](../ARCHITECTURE.md)** - Understand buildpack architecture
- **[Contributing](../CONTRIBUTING.md)** - Contribution guidelines and code standards

## Reference Implementations

Study these existing frameworks for examples:

**Simple Frameworks:**
- `debug.go` - Configuration-based, no dependencies
- `jmx.go` - Configuration-based, JMX enablement

**Service-Bound Frameworks:**
- `new_relic.go` - New Relic APM agent
- `app_dynamics_agent.go` - AppDynamics agent
- `seeker_security_provider.go` - IAST agent

**Complex Frameworks:**
- `luna_security_provider.go` - HSM integration with certificates
- `protect_app_security_provider.go` - Key management
- `container_customizer.go` - File-based detection

**All framework implementations**: `src/java/frameworks/`
