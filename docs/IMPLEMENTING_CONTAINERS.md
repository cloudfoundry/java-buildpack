# Implementing Containers

This guide explains how to implement new container support in the Cloud Foundry Java Buildpack. Containers are responsible for detecting application types and configuring their runtime execution environment.

## Table of Contents

- [Overview](#overview)
- [Container Interface](#container-interface)
- [Container Types](#container-types)
- [Implementation Steps](#implementation-steps)
- [Complete Examples](#complete-examples)
- [Common Patterns](#common-patterns)
- [Release Command Generation](#release-command-generation)
- [Testing Containers](#testing-containers)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

### What is a Container?

A container is a buildpack component that:
1. **Detects** the application type (Spring Boot JAR, Tomcat WAR, Java Main, etc.)
2. **Supplies** necessary runtime dependencies during staging
3. **Finalizes** the application for execution (classpath, launch command, environment)

### Existing Containers

The buildpack currently supports these container types:

| Container | Detection | Application Type |
|-----------|-----------|------------------|
| **Spring Boot** | BOOT-INF directory, spring-boot-*.jar | Spring Boot JARs and exploded JARs |
| **Tomcat** | WEB-INF directory, *.war files | Servlet applications and WARs |
| **Java Main** | Main-Class manifest, *.jar files | Standalone JAR applications |
| **DistZip** | bin/ + lib/ directories | Gradle/Maven distributions |
| **Groovy** | *.groovy files | Groovy scripts |
| **Play Framework** | start script + playVersion file | Play Framework apps |
| **Ratpack** | Ratpack.class | Ratpack applications |
| **Spring Boot CLI** | *.groovy + Spring annotations | Spring Boot CLI apps |

### Container Lifecycle

Containers participate in three phases:

1. **Detect Phase** - First container to successfully detect wins
2. **Supply Phase** - Install runtime dependencies (Tomcat, support libraries, etc.)
3. **Finalize Phase** - Generate launch command, set environment variables

## Container Interface

All containers must implement this interface:

```go
// src/java/containers/container.go
type Container interface {
    Detect() (string, error)  // Returns container name if detected
    Supply() error            // Install dependencies
    Finalize() error          // Configure runtime
    Release() (string, error) // Generate startup command
}
```

### Context Structure

Containers receive a `Context` struct:

```go
type Context struct {
    Stager    *libbuildpack.Stager     // Build directory access
    Manifest  *libbuildpack.Manifest   // Dependency versions
    Installer *libbuildpack.Installer  // Install dependencies
    Log       *libbuildpack.Logger     // Logging
    Command   *libbuildpack.Command    // Execute commands
}
```

**Key Context Methods:**

```go
// Build and deps directories
buildDir := ctx.Stager.BuildDir()     // /tmp/staging
depsDir := ctx.Stager.DepDir()        // /tmp/staging/deps/0
depsIdx := ctx.Stager.DepsIdx()       // "0"

// Environment and profile.d scripts
ctx.Stager.WriteEnvFile("VAR", "value")
ctx.Stager.WriteProfileD("script.sh", "export VAR=value")

// Logging
ctx.Log.BeginStep("Installing Container")
ctx.Log.Info("Installed version %s", version)
```

## Container Types

### Type 1: JAR-Based Containers

Run standalone JAR applications.

**Examples:** Spring Boot, Java Main

**Detection:** 
- JAR files in root directory
- MANIFEST.MF with Main-Class or Spring-Boot-Version
- BOOT-INF directory (Spring Boot)

**Launch:** `java -jar application.jar`

### Type 2: Server-Based Containers

Install and configure application servers.

**Examples:** Tomcat, Play Framework

**Detection:**
- WEB-INF directory (Tomcat)
- server/conf/ structure (Play)

**Launch:** Server-specific startup script or command

### Type 3: Script-Based Containers

Execute applications via startup scripts.

**Examples:** DistZip, Groovy, Spring Boot CLI

**Detection:**
- bin/ directory with executable scripts
- Script files (*.groovy)

**Launch:** Execute startup script

## Implementation Steps

### Step 1: Create Container Structure

Create `src/java/containers/my_container.go`:

```go
package containers

import (
    "fmt"
    "os"
    "path/filepath"
)

// MyContainer implements support for My application type
type MyContainer struct {
    context *Context
}

// NewMyContainer creates a new instance
func NewMyContainer(ctx *Context) *MyContainer {
    return &MyContainer{context: ctx}
}

// Detect checks if this is a My application
func (m *MyContainer) Detect() (string, error) {
    // TODO: Implement detection
    return "", nil
}

// Supply installs container dependencies
func (m *MyContainer) Supply() error {
    // TODO: Implement supply
    return nil
}

// Finalize configures runtime
func (m *MyContainer) Finalize() error {
    // TODO: Implement finalize
    return nil
}

// Release generates the command to start the application
func (m *MyContainer) Release() (string, error) {
    // TODO: Implement launch command
    return "", nil
}
```

### Step 2: Implement Detection

Detection determines if the application matches this container type:

**File-Based Detection:**
```go
func (m *MyContainer) Detect() (string, error) {
    buildDir := m.context.Stager.BuildDir()
    
    // Check for marker file/directory
    markerPath := filepath.Join(buildDir, "WEB-INF")
    if _, err := os.Stat(markerPath); err == nil {
        m.context.Log.Debug("Detected My application via WEB-INF directory")
        return "My Container", nil
    }
    
    return "", nil
}
```

**Pattern-Based Detection:**
```go
func (m *MyContainer) Detect() (string, error) {
    buildDir := m.context.Stager.BuildDir()
    
    // Check for specific file patterns
    matches, err := filepath.Glob(filepath.Join(buildDir, "*.myapp"))
    if err == nil && len(matches) > 0 {
        m.context.Log.Debug("Detected My application: %s", matches[0])
        return "My Container", nil
    }
    
    return "", nil
}
```

**Manifest-Based Detection:**
```go
func (m *MyContainer) Detect() (string, error) {
    buildDir := m.context.Stager.BuildDir()
    
    // Read MANIFEST.MF
    manifestPath := filepath.Join(buildDir, "META-INF", "MANIFEST.MF")
    data, err := os.ReadFile(manifestPath)
    if err != nil {
        return "", nil
    }
    
    // Check for specific manifest entry
    if strings.Contains(string(data), "My-Container-Version:") {
        return "My Container", nil
    }
    
    return "", nil
}
```

### Step 3: Implement Supply Phase

Install dependencies needed at runtime:

```go
func (m *MyContainer) Supply() error {
    m.context.Log.BeginStep("Supplying My Container")
    
    // Get dependency version from manifest
    dep, err := m.context.Manifest.DefaultVersion("my-server")
    if err != nil {
        return fmt.Errorf("unable to determine version: %w", err)
    }
    
    // Install to deps directory
    serverDir := filepath.Join(m.context.Stager.DepDir(), "my_server")
    if err := m.context.Installer.InstallDependency(dep, serverDir); err != nil {
        return fmt.Errorf("failed to install server: %w", err)
    }
    
    m.context.Log.Info("Installed My Server version %s", dep.Version)
    
    // Write profile.d script for runtime environment
    depsIdx := m.context.Stager.DepsIdx()
    envScript := fmt.Sprintf(`export MY_SERVER_HOME="$DEPS_DIR/%s/my_server"
export PATH="$MY_SERVER_HOME/bin:$PATH"
`, depsIdx)
    
    if err := m.context.Stager.WriteProfileD("my_server.sh", envScript); err != nil {
        return fmt.Errorf("failed to write profile.d script: %w", err)
    }
    
    return nil
}
```

### Step 4: Implement Finalize Phase

Configure the application for execution:

```go
func (m *MyContainer) Finalize() error {
    m.context.Log.BeginStep("Finalizing My Container")
    
    // Build classpath
    classpath, err := m.buildClasspath()
    if err != nil {
        return fmt.Errorf("failed to build classpath: %w", err)
    }
    
    // Write environment variables
    if err := m.context.Stager.WriteEnvFile("CLASSPATH", classpath); err != nil {
        return fmt.Errorf("failed to write CLASSPATH: %w", err)
    }
    
    return nil
}

func (m *MyContainer) buildClasspath() (string, error) {
    buildDir := m.context.Stager.BuildDir()
    
    var entries []string
    
    // Add lib directory
    libDir := filepath.Join(buildDir, "lib")
    if _, err := os.Stat(libDir); err == nil {
        entries = append(entries, "$HOME/lib/*")
    }
    
    return strings.Join(entries, ":"), nil
}
```

### Step 5: Implement Release Command

Generate the command to start the application:

```go
func (m *MyContainer) Release() (string, error) {
    buildDir := m.context.Stager.BuildDir()
    
    // Find main JAR or script
    jarFile := filepath.Join("$HOME", "application.jar")
    
    // Build java command with options
    javaOpts := os.Getenv("JAVA_OPTS")
    
    command := fmt.Sprintf("java %s -jar %s", javaOpts, jarFile)
    
    m.context.Log.Debug("Launch command: %s", command)
    return command, nil
}
```

### Step 6: Register Container

Add to `src/java/containers/registry.go`:

```go
func (r *Registry) RegisterAll() {
    r.Register(NewSpringBootContainer(r.context))
    r.Register(NewTomcatContainer(r.context))
    r.Register(NewMyContainer(r.context))  // Add your container
    r.Register(NewJavaMainContainer(r.context))
    // ...
}
```

**Note:** Container order matters! Place more specific containers before generic ones.

### Step 7: Add Tests

Create `src/java/containers/my_container_test.go`:

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

var _ = Describe("MyContainer", func() {
    var (
        ctx      *containers.Context
        buildDir string
    )
    
    BeforeEach(func() {
        var err error
        buildDir, err = os.MkdirTemp("", "build")
        Expect(err).NotTo(HaveOccurred())
        
        logger := libbuildpack.NewLogger(os.Stdout)
        stager := libbuildpack.NewStager(
            []string{buildDir, "", "0"},
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
    })
    
    Context("detection", func() {
        Context("with marker file", func() {
            BeforeEach(func() {
                os.MkdirAll(filepath.Join(buildDir, "MY-APP"), 0755)
            })
            
            It("detects the container", func() {
                container := containers.NewMyContainer(ctx)
                name, err := container.Detect()
                
                Expect(err).NotTo(HaveOccurred())
                Expect(name).To(Equal("My Container"))
            })
        })
        
        Context("without marker", func() {
            It("does not detect", func() {
                container := containers.NewMyContainer(ctx)
                name, err := container.Detect()
                
                Expect(err).NotTo(HaveOccurred())
                Expect(name).To(BeEmpty())
            })
        })
    })
})
```

## Complete Examples

### Example 1: Java Main Container (Simple)

A minimal container for standalone JAR applications.

**File**: `src/java/containers/java_main.go:1`

```go
package containers

import (
    "fmt"
    "os"
    "path/filepath"
    "strings"
)

type JavaMainContainer struct {
    context   *Context
    mainClass string
    jarFile   string
}

func NewJavaMainContainer(ctx *Context) *JavaMainContainer {
    return &JavaMainContainer{context: ctx}
}

// Detect: Look for JAR files or Main-Class manifest
func (j *JavaMainContainer) Detect() (string, error) {
    buildDir := j.context.Stager.BuildDir()
    
    // Look for JAR files
    mainClass, jarFile := j.findMainClass(buildDir)
    if mainClass != "" {
        j.mainClass = mainClass
        j.jarFile = jarFile
        j.context.Log.Debug("Detected Java Main: %s (main: %s)", jarFile, mainClass)
        return "Java Main", nil
    }
    
    // Check for META-INF/MANIFEST.MF with Main-Class
    manifestPath := filepath.Join(buildDir, "META-INF", "MANIFEST.MF")
    if _, err := os.Stat(manifestPath); err == nil {
        if mainClass := j.readMainClassFromManifest(manifestPath); mainClass != "" {
            j.mainClass = mainClass
            return "Java Main", nil
        }
    }
    
    // Check for compiled .class files
    classFiles, _ := filepath.Glob(filepath.Join(buildDir, "*.class"))
    if len(classFiles) > 0 {
        return "Java Main", nil
    }
    
    return "", nil
}

func (j *JavaMainContainer) findMainClass(buildDir string) (string, string) {
    entries, err := os.ReadDir(buildDir)
    if err != nil {
        return "", ""
    }
    
    for _, entry := range entries {
        if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".jar") {
            // In full implementation: extract and read MANIFEST.MF
            return "Main", filepath.Join("$HOME", entry.Name())
        }
    }
    
    return "", ""
}

func (j *JavaMainContainer) readMainClassFromManifest(path string) string {
    data, err := os.ReadFile(path)
    if err != nil {
        return ""
    }
    
    for _, line := range strings.Split(string(data), "\n") {
        if strings.HasPrefix(line, "Main-Class:") {
            return strings.TrimSpace(strings.TrimPrefix(line, "Main-Class:"))
        }
    }
    
    return ""
}

// Supply: No dependencies needed for Java Main
func (j *JavaMainContainer) Supply() error {
    j.context.Log.BeginStep("Supplying Java Main")
    return nil
}

// Finalize: Set up classpath
func (j *JavaMainContainer) Finalize() error {
    j.context.Log.BeginStep("Finalizing Java Main")
    
    classpath, err := j.buildClasspath()
    if err != nil {
        return fmt.Errorf("failed to build classpath: %w", err)
    }
    
    if err := j.context.Stager.WriteEnvFile("CLASSPATH", classpath); err != nil {
        return fmt.Errorf("failed to write CLASSPATH: %w", err)
    }
    
    return nil
}

func (j *JavaMainContainer) buildClasspath() (string, error) {
    var entries []string
    
    // Add current directory
    entries = append(entries, ".")
    
    // Add all JARs in lib/
    entries = append(entries, "$HOME/lib/*")
    
    return strings.Join(entries, ":"), nil
}

// Release: Generate java -jar or java -cp command
func (j *JavaMainContainer) Release() (string, error) {
    javaOpts := os.Getenv("JAVA_OPTS")
    
    if j.jarFile != "" {
        // JAR file execution
        return fmt.Sprintf("java %s -jar %s", javaOpts, j.jarFile), nil
    }
    
    if j.mainClass != "" {
        // Class file execution
        return fmt.Sprintf("java %s -cp $CLASSPATH %s", javaOpts, j.mainClass), nil
    }
    
    return "", fmt.Errorf("no main class or JAR file found")
}
```

**Key Points:**
- ✅ Simple detection (JAR files or Main-Class)
- ✅ Minimal supply phase (no dependencies)
- ✅ Classpath configuration
- ✅ Flexible launch command (JAR or class)

---

### Example 2: Tomcat Container (Server-Based)

Installs Tomcat server and deploys WARs.

**File**: `src/java/containers/tomcat.go:1`

```go
package containers

import (
    "fmt"
    "os"
    "path/filepath"
    
    "github.com/cloudfoundry/java-buildpack/src/java/jres"
    "github.com/cloudfoundry/libbuildpack"
)

type TomcatContainer struct {
    context *Context
}

func NewTomcatContainer(ctx *Context) *TomcatContainer {
    return &TomcatContainer{context: ctx}
}

// Detect: Look for WEB-INF or WAR files
func (t *TomcatContainer) Detect() (string, error) {
    buildDir := t.context.Stager.BuildDir()
    
    // Check for WEB-INF directory (exploded WAR)
    webInf := filepath.Join(buildDir, "WEB-INF")
    if _, err := os.Stat(webInf); err == nil {
        t.context.Log.Debug("Detected WAR via WEB-INF directory")
        return "Tomcat", nil
    }
    
    // Check for WAR files
    matches, _ := filepath.Glob(filepath.Join(buildDir, "*.war"))
    if len(matches) > 0 {
        t.context.Log.Debug("Detected WAR file: %s", matches[0])
        return "Tomcat", nil
    }
    
    return "", nil
}

// Supply: Install Tomcat server
func (t *TomcatContainer) Supply() error {
    t.context.Log.BeginStep("Supplying Tomcat")
    
    // Select Tomcat version based on Java version
    javaHome := os.Getenv("JAVA_HOME")
    var dep libbuildpack.Dependency
    var err error
    
    if javaHome != "" {
        javaMajorVersion, _ := jres.DetermineJavaVersion(javaHome)
        
        // Tomcat 10.x for Java 11+, Tomcat 9.x for Java 8-10
        versionPattern := "9.x"
        if javaMajorVersion >= 11 {
            versionPattern = "10.x"
            t.context.Log.Info("Using Tomcat 10.x for Java %d", javaMajorVersion)
        } else {
            t.context.Log.Info("Using Tomcat 9.x for Java %d", javaMajorVersion)
        }
        
        // Resolve version pattern
        allVersions := t.context.Manifest.AllDependencyVersions("tomcat")
        resolvedVersion, err := libbuildpack.FindMatchingVersion(versionPattern, allVersions)
        if err == nil {
            dep.Name = "tomcat"
            dep.Version = resolvedVersion
        }
    }
    
    // Fallback to default version
    if dep.Version == "" {
        dep, err = t.context.Manifest.DefaultVersion("tomcat")
        if err != nil {
            return fmt.Errorf("unable to determine Tomcat version: %w", err)
        }
    }
    
    // Install Tomcat (strip top-level directory from tarball)
    tomcatDir := filepath.Join(t.context.Stager.DepDir(), "tomcat")
    if err := t.context.Installer.InstallDependencyWithStrip(dep, tomcatDir, 1); err != nil {
        return fmt.Errorf("failed to install Tomcat: %w", err)
    }
    
    t.context.Log.Info("Installed Tomcat version %s", dep.Version)
    
    // Write profile.d script
    depsIdx := t.context.Stager.DepsIdx()
    tomcatPath := fmt.Sprintf("$DEPS_DIR/%s/tomcat", depsIdx)
    
    envScript := fmt.Sprintf(`export CATALINA_HOME=%s
export CATALINA_BASE=%s
`, tomcatPath, tomcatPath)
    
    if err := t.context.Stager.WriteProfileD("tomcat.sh", envScript); err != nil {
        return fmt.Errorf("failed to write tomcat.sh: %w", err)
    }
    
    // Install Tomcat support libraries
    t.installTomcatSupport()
    
    return nil
}

func (t *TomcatContainer) installTomcatSupport() error {
    dep, err := t.context.Manifest.DefaultVersion("tomcat-lifecycle-support")
    if err != nil {
        return err
    }
    
    supportDir := filepath.Join(t.context.Stager.DepDir(), "tomcat-lifecycle-support")
    if err := t.context.Installer.InstallDependency(dep, supportDir); err != nil {
        return fmt.Errorf("failed to install Tomcat support: %w", err)
    }
    
    t.context.Log.Info("Installed Tomcat Lifecycle Support %s", dep.Version)
    return nil
}

// Finalize: Configure Tomcat for application
func (t *TomcatContainer) Finalize() error {
    t.context.Log.BeginStep("Finalizing Tomcat")
    
    // Deploy application to Tomcat webapps
    if err := t.deployApplication(); err != nil {
        return err
    }
    
    return nil
}

func (t *TomcatContainer) deployApplication() error {
    buildDir := t.context.Stager.BuildDir()
    tomcatDir := filepath.Join(t.context.Stager.DepDir(), "tomcat")
    webappsDir := filepath.Join(tomcatDir, "webapps", "ROOT")
    
    // Copy application to webapps/ROOT
    if err := os.MkdirAll(webappsDir, 0755); err != nil {
        return fmt.Errorf("failed to create webapps directory: %w", err)
    }
    
    // Copy WEB-INF and other files
    // (Implementation would recursively copy files)
    
    t.context.Log.Debug("Deployed application to Tomcat webapps/ROOT")
    return nil
}

// Release: Start Tomcat
func (t *TomcatContainer) Release() (string, error) {
    depsIdx := t.context.Stager.DepsIdx()
    catalinaHome := fmt.Sprintf("$DEPS_DIR/%s/tomcat", depsIdx)
    
    command := fmt.Sprintf("%s/bin/catalina.sh run", catalinaHome)
    
    return command, nil
}
```

**Key Points:**
- ✅ Version selection based on Java version
- ✅ Installs Tomcat server during Supply
- ✅ Deploys application to webapps/ROOT
- ✅ Launches Tomcat with catalina.sh

---

### Example 3: Spring Boot Container (JAR-Based)

Handles Spring Boot executable JARs.

**File**: `src/java/containers/spring_boot.go:1`

```go
package containers

import (
    "fmt"
    "os"
    "path/filepath"
    "strings"
)

type SpringBootContainer struct {
    context     *Context
    jarFile     string
    startScript string
}

func NewSpringBootContainer(ctx *Context) *SpringBootContainer {
    return &SpringBootContainer{context: ctx}
}

// Detect: Multiple detection strategies
func (s *SpringBootContainer) Detect() (string, error) {
    buildDir := s.context.Stager.BuildDir()
    
    // Strategy 1: BOOT-INF directory (exploded Spring Boot JAR)
    bootInf := filepath.Join(buildDir, "BOOT-INF")
    if _, err := os.Stat(bootInf); err == nil {
        if s.isSpringBootExplodedJar(buildDir) {
            s.context.Log.Debug("Detected Spring Boot via BOOT-INF")
            return "Spring Boot", nil
        }
    }
    
    // Strategy 2: Spring Boot JAR in root
    jarFile, err := s.findSpringBootJar(buildDir)
    if err == nil && jarFile != "" {
        s.jarFile = jarFile
        s.context.Log.Debug("Detected Spring Boot JAR: %s", jarFile)
        return "Spring Boot", nil
    }
    
    // Strategy 3: Staged application (bin/ + lib/ with spring-boot-*.jar)
    if s.hasSpringBootInLib(buildDir) {
        startScript, _ := s.findStartupScript(buildDir)
        if startScript != "" {
            s.startScript = startScript
            s.context.Log.Debug("Detected staged Spring Boot app: %s", startScript)
            return "Spring Boot", nil
        }
    }
    
    return "", nil
}

func (s *SpringBootContainer) isSpringBootExplodedJar(buildDir string) bool {
    manifestPath := filepath.Join(buildDir, "META-INF", "MANIFEST.MF")
    data, err := os.ReadFile(manifestPath)
    if err != nil {
        return false
    }
    
    content := string(data)
    return strings.Contains(content, "Spring-Boot-Version:") ||
           strings.Contains(content, "Start-Class:")
}

func (s *SpringBootContainer) findSpringBootJar(buildDir string) (string, error) {
    entries, err := os.ReadDir(buildDir)
    if err != nil {
        return "", err
    }
    
    for _, entry := range entries {
        if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".jar") {
            jarPath := filepath.Join(buildDir, entry.Name())
            if s.isSpringBootJar(jarPath) {
                return filepath.Join("$HOME", entry.Name()), nil
            }
        }
    }
    
    return "", nil
}

func (s *SpringBootContainer) isSpringBootJar(jarPath string) bool {
    // Check file name patterns
    name := filepath.Base(jarPath)
    return strings.Contains(strings.ToLower(name), "spring") ||
           strings.Contains(strings.ToLower(name), "boot")
}

func (s *SpringBootContainer) hasSpringBootInLib(buildDir string) bool {
    libDirs := []string{
        filepath.Join(buildDir, "lib"),
        filepath.Join(buildDir, "WEB-INF", "lib"),
        filepath.Join(buildDir, "BOOT-INF", "lib"),
    }
    
    for _, libDir := range libDirs {
        entries, err := os.ReadDir(libDir)
        if err != nil {
            continue
        }
        
        for _, entry := range entries {
            name := entry.Name()
            if strings.HasPrefix(name, "spring-boot-") && strings.HasSuffix(name, ".jar") {
                return true
            }
        }
    }
    
    return false
}

func (s *SpringBootContainer) findStartupScript(buildDir string) (string, error) {
    binDir := filepath.Join(buildDir, "bin")
    entries, err := os.ReadDir(binDir)
    if err != nil {
        return "", err
    }
    
    for _, entry := range entries {
        if !entry.IsDir() && filepath.Ext(entry.Name()) != ".bat" {
            return entry.Name(), nil
        }
    }
    
    return "", fmt.Errorf("no startup script found")
}

// Supply: No dependencies needed
func (s *SpringBootContainer) Supply() error {
    s.context.Log.BeginStep("Supplying Spring Boot")
    return nil
}

// Finalize: Minimal configuration
func (s *SpringBootContainer) Finalize() error {
    s.context.Log.BeginStep("Finalizing Spring Boot")
    
    // Spring Boot apps are self-contained
    // No additional configuration needed
    
    return nil
}

// Release: Execute Spring Boot JAR or script
func (s *SpringBootContainer) Release() (string, error) {
    javaOpts := os.Getenv("JAVA_OPTS")
    
    // JAR file execution
    if s.jarFile != "" {
        return fmt.Sprintf("java %s -jar %s", javaOpts, s.jarFile), nil
    }
    
    // Staged app execution (via bin/ script)
    if s.startScript != "" {
        return fmt.Sprintf("$HOME/bin/%s", s.startScript), nil
    }
    
    // Exploded JAR execution
    return fmt.Sprintf("java %s org.springframework.boot.loader.JarLauncher", javaOpts), nil
}
```

**Key Points:**
- ✅ Multiple detection strategies (BOOT-INF, JAR, staged)
- ✅ Self-contained (no dependencies to install)
- ✅ Flexible launch (JAR, script, or JarLauncher)
- ✅ Handles various Spring Boot packaging formats

## Common Patterns

### Pattern 1: File/Directory Detection

```go
func (c *MyContainer) Detect() (string, error) {
    buildDir := c.context.Stager.BuildDir()
    
    // Check for specific directory
    markerDir := filepath.Join(buildDir, "WEB-INF")
    if _, err := os.Stat(markerDir); err == nil {
        return "My Container", nil
    }
    
    return "", nil
}
```

### Pattern 2: Installing Server/Runtime

```go
func (c *MyContainer) Supply() error {
    // Get version from manifest
    dep, err := c.context.Manifest.DefaultVersion("my-server")
    if err != nil {
        return fmt.Errorf("unable to determine version: %w", err)
    }
    
    // Install with strip (removes top-level directory from tarball)
    serverDir := filepath.Join(c.context.Stager.DepDir(), "my_server")
    if err := c.context.Installer.InstallDependencyWithStrip(dep, serverDir, 1); err != nil {
        return fmt.Errorf("failed to install: %w", err)
    }
    
    return nil
}
```

### Pattern 3: Writing Profile.d Scripts

```go
func (c *MyContainer) Supply() error {
    depsIdx := c.context.Stager.DepsIdx()
    
    script := fmt.Sprintf(`export MY_HOME="$DEPS_DIR/%s/my_server"
export PATH="$MY_HOME/bin:$PATH"
`, depsIdx)
    
    return c.context.Stager.WriteProfileD("my_container.sh", script)
}
```

### Pattern 4: Building Classpath

```go
func (c *MyContainer) buildClasspath() (string, error) {
    var entries []string
    
    // Add current directory
    entries = append(entries, ".")
    
    // Add lib directory
    entries = append(entries, "$HOME/lib/*")
    
    // Add BOOT-INF directories (if present)
    entries = append(entries, "$HOME/BOOT-INF/classes")
    entries = append(entries, "$HOME/BOOT-INF/lib/*")
    
    return strings.Join(entries, ":"), nil
}
```

### Pattern 5: Manifest Parsing

```go
func (c *MyContainer) readManifest(manifestPath string) map[string]string {
    data, err := os.ReadFile(manifestPath)
    if err != nil {
        return nil
    }
    
    manifest := make(map[string]string)
    
    for _, line := range strings.Split(string(data), "\n") {
        line = strings.TrimSpace(line)
        if strings.Contains(line, ":") {
            parts := strings.SplitN(line, ":", 2)
            key := strings.TrimSpace(parts[0])
            value := strings.TrimSpace(parts[1])
            manifest[key] = value
        }
    }
    
    return manifest
}
```

## Release Command Generation

### Simple JAR Execution

```go
func (c *MyContainer) Release() (string, error) {
    javaOpts := os.Getenv("JAVA_OPTS")
    jarFile := "$HOME/application.jar"
    
    return fmt.Sprintf("java %s -jar %s", javaOpts, jarFile), nil
}
```

### Server Startup Script

```go
func (c *MyContainer) Release() (string, error) {
    depsIdx := c.context.Stager.DepsIdx()
    serverHome := fmt.Sprintf("$DEPS_DIR/%s/server", depsIdx)
    
    return fmt.Sprintf("%s/bin/start.sh", serverHome), nil
}
```

### Class Execution with Classpath

```go
func (c *MyContainer) Release() (string, error) {
    javaOpts := os.Getenv("JAVA_OPTS")
    mainClass := c.mainClass
    
    return fmt.Sprintf("java %s -cp $CLASSPATH %s", javaOpts, mainClass), nil
}
```

### Application-Specific Script

```go
func (c *MyContainer) Release() (string, error) {
    scriptName := c.findScript()
    
    return fmt.Sprintf("$HOME/bin/%s", scriptName), nil
}
```

## Testing Containers

### Basic Container Test

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

var _ = Describe("MyContainer", func() {
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
    
    Describe("Detection", func() {
        Context("with valid application", func() {
            BeforeEach(func() {
                // Create application structure
                os.MkdirAll(filepath.Join(buildDir, "MY-APP"), 0755)
            })
            
            It("detects the container", func() {
                container := containers.NewMyContainer(ctx)
                name, err := container.Detect()
                
                Expect(err).NotTo(HaveOccurred())
                Expect(name).To(Equal("My Container"))
            })
        })
        
        Context("without markers", func() {
            It("does not detect", func() {
                container := containers.NewMyContainer(ctx)
                name, err := container.Detect()
                
                Expect(err).NotTo(HaveOccurred())
                Expect(name).To(BeEmpty())
            })
        })
    })
    
    Describe("Release Command", func() {
        It("generates correct command", func() {
            container := containers.NewMyContainer(ctx)
            command, err := container.Release()
            
            Expect(err).NotTo(HaveOccurred())
            Expect(command).To(ContainSubstring("java"))
        })
    })
})
```

### Integration Tests

Integration tests deploy real applications. See [docs/TESTING.md](TESTING.md) for details.

## Best Practices

### 1. Specific Detection

Make detection as specific as possible to avoid false positives:

```go
// GOOD - Multiple checks
func (c *MyContainer) Detect() (string, error) {
    hasMarkerDir := c.hasMarkerDir()
    hasRequiredJar := c.hasRequiredJar()
    
    if hasMarkerDir && hasRequiredJar {
        return "My Container", nil
    }
    
    return "", nil
}

// BAD - Too generic
func (c *MyContainer) Detect() (string, error) {
    // Detects any JAR file
    matches, _ := filepath.Glob("*.jar")
    if len(matches) > 0 {
        return "My Container", nil
    }
    return "", nil
}
```

### 2. Container Order Matters

Register more specific containers before generic ones:

```go
// GOOD order
r.Register(NewSpringBootContainer(r.context))  // Specific
r.Register(NewTomcatContainer(r.context))      // Specific
r.Register(NewJavaMainContainer(r.context))    // Generic (fallback)

// BAD order - JavaMain would detect everything
r.Register(NewJavaMainContainer(r.context))    // Too generic, runs first
r.Register(NewSpringBootContainer(r.context))  // Never reached!
```

### 3. Use Runtime Paths

Use `$DEPS_DIR` and `$HOME` variables for paths:

```go
// GOOD - Uses runtime variables
tomcatPath := fmt.Sprintf("$DEPS_DIR/%s/tomcat", depsIdx)

// BAD - Hardcoded staging paths
tomcatPath := "/tmp/staging/deps/0/tomcat"  // Won't work at runtime!
```

### 4. Minimal Supply Phase

Only install what's necessary:

```go
// GOOD - Only installs if needed
func (c *MyContainer) Supply() error {
    if c.needsServer() {
        return c.installServer()
    }
    return nil
}

// BAD - Installs everything
func (c *MyContainer) Supply() error {
    c.installServer()
    c.installSupport()
    c.installUtilities()
    // ... too much
}
```

### 5. Clear Logging

Log what's happening at each phase:

```go
c.context.Log.BeginStep("Installing Tomcat")     // Major steps
c.context.Log.Info("Installed version %s", ver)  // Important info
c.context.Log.Debug("Found file: %s", path)      // Debug details
c.context.Log.Warning("Feature disabled")        // Warnings
```

## Troubleshooting

### Container Not Detected

**Check:**
1. Is detection logic correct? Add debug logging
2. Are required files present? Check with `cf files`
3. Is container registered in registry?
4. Is another container detecting first? Check order

### Supply Phase Fails

**Check:**
1. Is dependency in manifest? Check `manifest.yml`
2. Is download URL accessible?
3. Are permissions correct (0755 for directories)?
4. Check logs: `cf logs my-app --recent`

### Release Command Fails

**Check:**
1. Are paths using runtime variables (`$DEPS_DIR`, `$HOME`)?
2. Is classpath correct? Check `CLASSPATH` env var
3. Is `JAVA_OPTS` set correctly?
4. Test command: `cf ssh my-app` then manually run command

### Wrong Container Detected

**Problem:** Generic container detecting before specific one

**Solution:** Reorder container registration - specific before generic

## Next Steps

- **[Implementing JREs](IMPLEMENTING_JRES.md)** - Add new JRE providers
- **[Implementing Frameworks](IMPLEMENTING_FRAMEWORKS.md)** - Add framework integrations
- **[Testing Guide](TESTING.md)** - Comprehensive testing strategies
- **[Architecture](../ARCHITECTURE.md)** - Understand buildpack design
- **[Contributing](../CONTRIBUTING.md)** - Contribution guidelines

## Reference Implementations

Study these existing containers:

**Simple Containers:**
- `java_main.go` - Standalone JAR applications
- `groovy.go` - Groovy script execution

**Server Containers:**
- `tomcat.go` - Servlet container with server installation
- `play.go` - Play Framework with native packager

**Complex Containers:**
- `spring_boot.go` - Multiple detection strategies
- `dist_zip.go` - Gradle/Maven distribution handling

**All container implementations**: `src/java/containers/`
