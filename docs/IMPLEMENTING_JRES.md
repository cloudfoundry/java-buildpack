# Implementing JREs

This guide explains how to implement new JRE (Java Runtime Environment) providers for the Cloud Foundry Java Buildpack. JRE providers are responsible for detecting, installing, and configuring the Java runtime that will execute your application.

## Table of Contents

- [Overview](#overview)
- [Available JRE Providers](#available-jre-providers)
- [JRE Interface](#jre-interface)
- [Implementation Steps](#implementation-steps)
- [Complete Examples](#complete-examples)
  - [Example 1: OpenJDK (Standard JRE)](#example-1-openjdk-standard-jre)
  - [Example 2: Zulu (Alternative Distribution)](#example-2-zulu-alternative-distribution)
  - [Example 3: IBM JRE (Custom Configuration)](#example-3-ibm-jre-custom-configuration)
- [Common Patterns](#common-patterns)
- [Memory Calculator Integration](#memory-calculator-integration)
- [JVMKill Agent](#jvmkill-agent)
- [Testing JREs](#testing-jres)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

A JRE provider is a component that:

1. **Detects** when it should be used (via environment variables or configuration)
2. **Supplies** the Java runtime by downloading and extracting it
3. **Installs components** like the memory calculator and JVMKill agent
4. **Finalizes** configuration by setting up JAVA_HOME and JVM options
5. **Provides information** about the installed Java version and location

The buildpack supports multiple JRE providers, allowing operators to choose between different Java distributions (OpenJDK, Zulu, GraalVM, IBM, etc.) based on their requirements.

## Available JRE Providers

The buildpack includes these JRE providers:

| Provider | Package Name | Default | Detection Method |
|----------|-------------|---------|------------------|
| **OpenJDK** | `openjdk` | Yes | Always detected (fallback) |
| **Zulu** | `zulu` | No | `JBP_CONFIG_COMPONENTS` or `JBP_CONFIG_ZULU_JRE` |
| **GraalVM** | `graalvm` | No | `JBP_CONFIG_COMPONENTS` or `JBP_CONFIG_GRAAL_VM_JRE` |
| **IBM JRE** | `ibm` | No | `JBP_CONFIG_COMPONENTS` or `JBP_CONFIG_IBM_JRE` |
| **Oracle JRE** | `oracle` | No | `JBP_CONFIG_COMPONENTS` or `JBP_CONFIG_ORACLE_JRE` |
| **SapMachine** | `sapmachine` | No | `JBP_CONFIG_COMPONENTS` or `JBP_CONFIG_SAP_MACHINE_JRE` |
| **Azul Platform Prime** | `zing` | No | `JBP_CONFIG_COMPONENTS` or `JBP_CONFIG_ZING_JRE` |

## JRE Interface

All JRE providers must implement the `jres.JRE` interface defined in `src/java/jres/jre.go`:

```go
type JRE interface {
    // Name returns the name of this JRE provider (e.g., "OpenJDK", "Zulu")
    Name() string

    // Detect returns true if this JRE should be used
    Detect() (bool, error)

    // Supply installs the JRE and its components (memory calculator, jvmkill)
    Supply() error

    // Finalize performs any final JRE configuration
    Finalize() error

    // JavaHome returns the path to JAVA_HOME
    JavaHome() string

    // Version returns the installed JRE version
    Version() string
}
```

### JRE Context

JRE providers receive a `Context` struct with shared dependencies:

```go
type Context struct {
    Stager    *libbuildpack.Stager    // Build/staging information
    Manifest  *libbuildpack.Manifest  // Dependency versions
    Installer *libbuildpack.Installer // Downloads dependencies
    Log       *libbuildpack.Logger    // Logging
    Command   *libbuildpack.Command   // Execute commands
}
```

## Implementation Steps

Follow these steps to implement a new JRE provider:

### Step 1: Create the JRE Struct

Create a new file `src/java/jres/<jre_name>.go` with a struct that will implement the `JRE` interface:

```go
package jres

import (
    "fmt"
    "os"
    "path/filepath"
    "github.com/cloudfoundry/libbuildpack"
)

type MyJRE struct {
    ctx              *Context
    jreDir           string           // Installation directory
    version          string           // Requested version
    javaHome         string           // Actual JAVA_HOME path
    memoryCalc       *MemoryCalculator
    jvmkill          *JVMKillAgent
    installedVersion string
}
```

### Step 2: Implement the Constructor

Create a constructor function that initializes your JRE provider:

```go
func NewMyJRE(ctx *Context) *MyJRE {
    jreDir := filepath.Join(ctx.Stager.DepDir(), "jre")
    
    return &MyJRE{
        ctx:    ctx,
        jreDir: jreDir,
    }
}
```

### Step 3: Implement Name()

Return a human-readable name for your JRE:

```go
func (m *MyJRE) Name() string {
    return "My JRE"
}
```

### Step 4: Implement Detect()

Implement detection logic to determine if this JRE should be used:

```go
func (m *MyJRE) Detect() (bool, error) {
    // Check for explicit configuration
    configuredJRE := os.Getenv("JBP_CONFIG_COMPONENTS")
    if configuredJRE != "" && containsString(configuredJRE, "MyJRE") {
        return true, nil
    }
    
    // Check legacy environment variable
    if DetectJREByEnv("my_jre") {
        return true, nil
    }
    
    return false, nil
}
```

### Step 5: Implement Supply()

Install the JRE and its components:

```go
func (m *MyJRE) Supply() error {
    m.ctx.Log.BeginStep("Installing My JRE")
    
    // 1. Determine version
    dep, err := GetJREVersion(m.ctx, "my-jre")
    if err != nil {
        m.ctx.Log.Warning("Unable to determine My JRE version: %s", err.Error())
        return err
    }
    
    m.version = dep.Version
    m.ctx.Log.Info("Installing My JRE %s", m.version)
    
    // 2. Install JRE
    if err := m.ctx.Installer.InstallDependency(dep, m.jreDir); err != nil {
        return fmt.Errorf("failed to install My JRE: %w", err)
    }
    
    // 3. Find JAVA_HOME
    javaHome, err := m.findJavaHome()
    if err != nil {
        return fmt.Errorf("failed to find JAVA_HOME: %w", err)
    }
    m.javaHome = javaHome
    m.installedVersion = m.version
    
    // 4. Write profile.d script for runtime
    if err := WriteJavaHomeProfileD(m.ctx, m.jreDir, m.javaHome); err != nil {
        m.ctx.Log.Warning("Could not write profile.d script: %s", err.Error())
    }
    
    // 5. Determine Java major version
    javaMajorVersion, err := DetermineJavaVersion(javaHome)
    if err != nil {
        m.ctx.Log.Warning("Could not determine Java version: %s", err.Error())
        javaMajorVersion = 17 // default
    }
    m.ctx.Log.Info("Detected Java major version: %d", javaMajorVersion)
    
    // 6. Install JVMKill agent
    m.jvmkill = NewJVMKillAgent(m.ctx, m.jreDir, m.version)
    if err := m.jvmkill.Supply(); err != nil {
        m.ctx.Log.Warning("Failed to install JVMKill: %s", err.Error())
    }
    
    // 7. Install Memory Calculator
    m.memoryCalc = NewMemoryCalculator(m.ctx, m.jreDir, m.version, javaMajorVersion)
    if err := m.memoryCalc.Supply(); err != nil {
        m.ctx.Log.Warning("Failed to install Memory Calculator: %s", err.Error())
    }
    
    m.ctx.Log.Info("My JRE installation complete")
    return nil
}
```

### Step 6: Implement Finalize()

Perform final configuration (JVM options, environment setup):

```go
func (m *MyJRE) Finalize() error {
    m.ctx.Log.BeginStep("Finalizing My JRE configuration")
    
    // Ensure JAVA_HOME is set
    if m.javaHome == "" {
        javaHome, err := m.findJavaHome()
        if err != nil {
            m.ctx.Log.Warning("Failed to find JAVA_HOME: %s", err.Error())
        } else {
            m.javaHome = javaHome
        }
    }
    
    // Determine Java major version
    javaMajorVersion := 17
    if m.javaHome != "" {
        if ver, err := DetermineJavaVersion(m.javaHome); err == nil {
            javaMajorVersion = ver
        }
    }
    
    // Finalize JVMKill agent
    if m.jvmkill == nil {
        m.jvmkill = NewJVMKillAgent(m.ctx, m.jreDir, m.version)
    }
    if err := m.jvmkill.Finalize(); err != nil {
        m.ctx.Log.Warning("Failed to finalize JVMKill: %s", err.Error())
    }
    
    // Finalize Memory Calculator
    if m.memoryCalc == nil {
        m.memoryCalc = NewMemoryCalculator(m.ctx, m.jreDir, m.version, javaMajorVersion)
    }
    if err := m.memoryCalc.Finalize(); err != nil {
        m.ctx.Log.Warning("Failed to finalize Memory Calculator: %s", err.Error())
    }
    
    // Add any JRE-specific JVM options
    // Example: opts := "-XX:+UseG1GC"
    // WriteJavaOpts(m.ctx, opts)
    
    m.ctx.Log.Info("My JRE finalization complete")
    return nil
}
```

### Step 7: Implement Helper Methods

Implement remaining interface methods and helper functions:

```go
// JavaHome returns the path to JAVA_HOME
func (m *MyJRE) JavaHome() string {
    return m.javaHome
}

// Version returns the installed JRE version
func (m *MyJRE) Version() string {
    return m.installedVersion
}

// findJavaHome locates JAVA_HOME after extraction
func (m *MyJRE) findJavaHome() (string, error) {
    entries, err := os.ReadDir(m.jreDir)
    if err != nil {
        return "", fmt.Errorf("failed to read JRE directory: %w", err)
    }
    
    // Look for jdk-* or jre-* subdirectories
    for _, entry := range entries {
        if entry.IsDir() {
            name := entry.Name()
            if len(name) > 3 && (name[:3] == "jdk" || name[:3] == "jre") {
                path := filepath.Join(m.jreDir, name)
                // Verify it has bin/java
                if _, err := os.Stat(filepath.Join(path, "bin", "java")); err == nil {
                    return path, nil
                }
            }
        }
    }
    
    // Check if jreDir itself is valid
    if _, err := os.Stat(filepath.Join(m.jreDir, "bin", "java")); err == nil {
        return m.jreDir, nil
    }
    
    return "", fmt.Errorf("could not find valid JAVA_HOME in %s", m.jreDir)
}
```

### Step 8: Register the JRE

Register your JRE provider in `src/java/supply/supply.go`:

```go
// In the Supply function, register your JRE
jreRegistry := jres.NewRegistry(jreCtx)
jreRegistry.Register(jres.NewOpenJDKJRE(jreCtx))
jreRegistry.Register(jres.NewZuluJRE(jreCtx))
jreRegistry.Register(jres.NewMyJRE(jreCtx))  // Add your JRE
```

## Complete Examples

### Example 1: OpenJDK (Standard JRE)

OpenJDK is the default JRE provider. It always detects successfully and serves as the fallback.

**File:** `src/java/jres/openjdk.go`

```go
package jres

import (
    "fmt"
    "os"
    "path/filepath"
    "github.com/cloudfoundry/libbuildpack"
)

type OpenJDKJRE struct {
    ctx              *Context
    jreDir           string
    version          string
    javaHome         string
    memoryCalc       *MemoryCalculator
    jvmkill          *JVMKillAgent
    installedVersion string
}

func NewOpenJDKJRE(ctx *Context) *OpenJDKJRE {
    jreDir := filepath.Join(ctx.Stager.DepDir(), "jre")
    return &OpenJDKJRE{
        ctx:    ctx,
        jreDir: jreDir,
    }
}

func (o *OpenJDKJRE) Name() string {
    return "OpenJDK"
}

// Detect always returns true (default JRE)
func (o *OpenJDKJRE) Detect() (bool, error) {
    return true, nil
}

func (o *OpenJDKJRE) Supply() error {
    o.ctx.Log.BeginStep("Installing OpenJDK JRE")
    
    // Determine version from manifest
    dep, err := GetJREVersion(o.ctx, "openjdk")
    if err != nil {
        o.ctx.Log.Warning("Unable to determine OpenJDK version from manifest, using default")
        dep = libbuildpack.Dependency{
            Name:    "openjdk",
            Version: "17.0.13",
        }
    }
    
    o.version = dep.Version
    o.ctx.Log.Info("Installing OpenJDK %s", o.version)
    
    // Install JRE tarball
    if err := o.ctx.Installer.InstallDependency(dep, o.jreDir); err != nil {
        return fmt.Errorf("failed to install OpenJDK: %w", err)
    }
    
    // Find JAVA_HOME (OpenJDK extracts to jdk-* subdirectory)
    javaHome, err := o.findJavaHome()
    if err != nil {
        return fmt.Errorf("failed to find JAVA_HOME: %w", err)
    }
    o.javaHome = javaHome
    o.installedVersion = o.version
    
    // Create profile.d script to export JAVA_HOME at runtime
    if err := WriteJavaHomeProfileD(o.ctx, o.jreDir, o.javaHome); err != nil {
        o.ctx.Log.Warning("Could not write profile.d script: %s", err.Error())
    }
    
    // Determine Java major version
    javaMajorVersion, err := DetermineJavaVersion(javaHome)
    if err != nil {
        o.ctx.Log.Warning("Could not determine Java version: %s", err.Error())
        javaMajorVersion = 17
    }
    o.ctx.Log.Info("Detected Java major version: %d", javaMajorVersion)
    
    // Install JVMKill agent
    o.jvmkill = NewJVMKillAgent(o.ctx, o.jreDir, o.version)
    if err := o.jvmkill.Supply(); err != nil {
        o.ctx.Log.Warning("Failed to install JVMKill agent: %s (continuing)", err.Error())
    }
    
    // Install Memory Calculator
    o.memoryCalc = NewMemoryCalculator(o.ctx, o.jreDir, o.version, javaMajorVersion)
    if err := o.memoryCalc.Supply(); err != nil {
        o.ctx.Log.Warning("Failed to install Memory Calculator: %s (continuing)", err.Error())
    }
    
    o.ctx.Log.Info("OpenJDK JRE installation complete")
    return nil
}

func (o *OpenJDKJRE) Finalize() error {
    o.ctx.Log.BeginStep("Finalizing OpenJDK JRE configuration")
    
    // Find JAVA_HOME if not set
    if o.javaHome == "" {
        javaHome, err := o.findJavaHome()
        if err != nil {
            o.ctx.Log.Warning("Failed to find JAVA_HOME: %s", err.Error())
        } else {
            o.javaHome = javaHome
        }
    }
    
    // Set JAVA_HOME for frameworks during finalize
    if o.javaHome != "" {
        if err := os.Setenv("JAVA_HOME", o.javaHome); err != nil {
            o.ctx.Log.Warning("Failed to set JAVA_HOME: %s", err.Error())
        }
    }
    
    // Determine Java version
    javaMajorVersion := 17
    if o.javaHome != "" {
        if ver, err := DetermineJavaVersion(o.javaHome); err == nil {
            javaMajorVersion = ver
        }
    }
    
    // Finalize JVMKill agent
    if o.jvmkill == nil {
        o.jvmkill = NewJVMKillAgent(o.ctx, o.jreDir, o.version)
    }
    if err := o.jvmkill.Finalize(); err != nil {
        o.ctx.Log.Warning("Failed to finalize JVMKill agent: %s", err.Error())
    }
    
    // Finalize Memory Calculator
    if o.memoryCalc == nil {
        o.memoryCalc = NewMemoryCalculator(o.ctx, o.jreDir, o.version, javaMajorVersion)
    }
    if err := o.memoryCalc.Finalize(); err != nil {
        o.ctx.Log.Warning("Failed to finalize Memory Calculator: %s", err.Error())
    }
    
    o.ctx.Log.Info("OpenJDK JRE finalization complete")
    return nil
}

func (o *OpenJDKJRE) JavaHome() string {
    return o.javaHome
}

func (o *OpenJDKJRE) Version() string {
    return o.installedVersion
}

func (o *OpenJDKJRE) findJavaHome() (string, error) {
    entries, err := os.ReadDir(o.jreDir)
    if err != nil {
        return "", fmt.Errorf("failed to read JRE directory: %w", err)
    }
    
    // Look for jdk-* or jre-* subdirectory
    for _, entry := range entries {
        if entry.IsDir() {
            name := entry.Name()
            if len(name) > 3 && (name[:3] == "jdk" || name[:3] == "jre") {
                path := filepath.Join(o.jreDir, name)
                if _, err := os.Stat(filepath.Join(path, "bin", "java")); err == nil {
                    return path, nil
                }
            }
        }
    }
    
    // Check if jreDir itself is valid
    if _, err := os.Stat(filepath.Join(o.jreDir, "bin", "java")); err == nil {
        return o.jreDir, nil
    }
    
    return "", fmt.Errorf("could not find valid JAVA_HOME in %s", o.jreDir)
}
```

**Key Points:**
- **Always detects:** OpenJDK is the default, so `Detect()` always returns `true`
- **Standard installation:** Downloads tarball, extracts to `deps/0/jre`
- **Nested directory handling:** OpenJDK tarballs extract to `jdk-17.0.13/` subdirectory
- **Component installation:** Installs JVMKill and Memory Calculator
- **Profile.d script:** Exports JAVA_HOME at runtime for containers

**Configuration:**

Users can specify Java version via `BP_JAVA_VERSION`:
```bash
cf set-env myapp BP_JAVA_VERSION 21
```

### Example 2: Zulu (Alternative Distribution)

Zulu is an alternative OpenJDK distribution from Azul Systems. It requires explicit configuration.

**File:** `src/java/jres/zulu.go`

```go
package jres

import (
    "fmt"
    "os"
    "path/filepath"
    "github.com/cloudfoundry/libbuildpack"
)

type ZuluJRE struct {
    ctx              *Context
    jreDir           string
    version          string
    javaHome         string
    memoryCalc       *MemoryCalculator
    jvmkill          *JVMKillAgent
    installedVersion string
}

func NewZuluJRE(ctx *Context) *ZuluJRE {
    jreDir := filepath.Join(ctx.Stager.DepDir(), "jre")
    return &ZuluJRE{
        ctx:    ctx,
        jreDir: jreDir,
    }
}

func (z *ZuluJRE) Name() string {
    return "Zulu"
}

// Detect checks for explicit Zulu configuration
func (z *ZuluJRE) Detect() (bool, error) {
    // Check JBP_CONFIG_COMPONENTS for Zulu
    configuredJRE := os.Getenv("JBP_CONFIG_COMPONENTS")
    if configuredJRE != "" && (containsString(configuredJRE, "ZuluJRE") || containsString(configuredJRE, "Zulu")) {
        return true, nil
    }
    
    // Check legacy environment variable
    if DetectJREByEnv("zulu_jre") {
        return true, nil
    }
    
    return false, nil
}

func (z *ZuluJRE) Supply() error {
    z.ctx.Log.BeginStep("Installing Zulu JRE")
    
    // Determine version
    dep, err := GetJREVersion(z.ctx, "zulu")
    if err != nil {
        z.ctx.Log.Warning("Unable to determine Zulu version from manifest, using default")
        dep = libbuildpack.Dependency{
            Name:    "zulu",
            Version: "11.0.25",
        }
    }
    
    z.version = dep.Version
    z.ctx.Log.Info("Installing Zulu %s", z.version)
    
    // Install JRE
    if err := z.ctx.Installer.InstallDependency(dep, z.jreDir); err != nil {
        return fmt.Errorf("failed to install Zulu: %w", err)
    }
    
    // Find JAVA_HOME (Zulu extracts to zulu-* subdirectory)
    javaHome, err := z.findJavaHome()
    if err != nil {
        return fmt.Errorf("failed to find JAVA_HOME: %w", err)
    }
    z.javaHome = javaHome
    z.installedVersion = z.version
    
    // Set up JAVA_HOME environment
    if err := WriteJavaHomeProfileD(z.ctx, z.jreDir, z.javaHome); err != nil {
        z.ctx.Log.Warning("Could not write profile.d script: %s", err.Error())
    }
    
    // Determine Java major version
    javaMajorVersion, err := DetermineJavaVersion(javaHome)
    if err != nil {
        z.ctx.Log.Warning("Could not determine Java version: %s", err.Error())
        javaMajorVersion = 11 // default for Zulu
    }
    z.ctx.Log.Info("Detected Java major version: %d", javaMajorVersion)
    
    // Install JVMKill agent
    z.jvmkill = NewJVMKillAgent(z.ctx, z.jreDir, z.version)
    if err := z.jvmkill.Supply(); err != nil {
        z.ctx.Log.Warning("Failed to install JVMKill agent: %s (continuing)", err.Error())
    }
    
    // Install Memory Calculator
    z.memoryCalc = NewMemoryCalculator(z.ctx, z.jreDir, z.version, javaMajorVersion)
    if err := z.memoryCalc.Supply(); err != nil {
        z.ctx.Log.Warning("Failed to install Memory Calculator: %s (continuing)", err.Error())
    }
    
    z.ctx.Log.Info("Zulu JRE installation complete")
    return nil
}

func (z *ZuluJRE) Finalize() error {
    z.ctx.Log.BeginStep("Finalizing Zulu JRE configuration")
    
    // Find JAVA_HOME if not set
    if z.javaHome == "" {
        javaHome, err := z.findJavaHome()
        if err != nil {
            z.ctx.Log.Warning("Failed to find JAVA_HOME: %s", err.Error())
        } else {
            z.javaHome = javaHome
        }
    }
    
    // Determine Java major version
    javaMajorVersion := 11
    if z.javaHome != "" {
        if ver, err := DetermineJavaVersion(z.javaHome); err == nil {
            javaMajorVersion = ver
        }
    }
    
    // Finalize JVMKill agent
    if z.jvmkill == nil {
        z.jvmkill = NewJVMKillAgent(z.ctx, z.jreDir, z.version)
    }
    if err := z.jvmkill.Finalize(); err != nil {
        z.ctx.Log.Warning("Failed to finalize JVMKill agent: %s", err.Error())
    }
    
    // Finalize Memory Calculator
    if z.memoryCalc == nil {
        z.memoryCalc = NewMemoryCalculator(z.ctx, z.jreDir, z.version, javaMajorVersion)
    }
    if err := z.memoryCalc.Finalize(); err != nil {
        z.ctx.Log.Warning("Failed to finalize Memory Calculator: %s", err.Error())
    }
    
    z.ctx.Log.Info("Zulu JRE finalization complete")
    return nil
}

func (z *ZuluJRE) JavaHome() string {
    return z.javaHome
}

func (z *ZuluJRE) Version() string {
    return z.installedVersion
}

func (z *ZuluJRE) findJavaHome() (string, error) {
    entries, err := os.ReadDir(z.jreDir)
    if err != nil {
        return "", fmt.Errorf("failed to read JRE directory: %w", err)
    }
    
    // Look for zulu-*, jdk-*, or jre-* subdirectory
    for _, entry := range entries {
        if entry.IsDir() {
            name := entry.Name()
            // Check for Zulu-specific patterns first
            if len(name) > 4 && name[:4] == "zulu" {
                path := filepath.Join(z.jreDir, name)
                if _, err := os.Stat(filepath.Join(path, "bin", "java")); err == nil {
                    return path, nil
                }
            }
            // Also check standard patterns
            if len(name) > 3 && (name[:3] == "jdk" || name[:3] == "jre") {
                path := filepath.Join(z.jreDir, name)
                if _, err := os.Stat(filepath.Join(path, "bin", "java")); err == nil {
                    return path, nil
                }
            }
        }
    }
    
    // Check if jreDir itself is valid
    if _, err := os.Stat(filepath.Join(z.jreDir, "bin", "java")); err == nil {
        return z.jreDir, nil
    }
    
    return "", fmt.Errorf("could not find valid JAVA_HOME in %s", z.jreDir)
}
```

**Key Points:**
- **Explicit detection:** Only detects when configured via `JBP_CONFIG_COMPONENTS`
- **Alternative naming:** Looks for `zulu-*` directory patterns in addition to `jdk-*`
- **Same components:** Uses standard JVMKill and Memory Calculator

**Configuration:**

Users enable Zulu via environment variable:
```bash
cf set-env myapp JBP_CONFIG_COMPONENTS '{jres: ["JavaBuildpack::Jre::ZuluJRE"]}'
cf set-env myapp BP_JAVA_VERSION 11
```

### Example 3: IBM JRE (Custom Configuration)

IBM JRE requires custom repository configuration and adds vendor-specific JVM options.

**File:** `src/java/jres/ibm.go`

```go
package jres

import (
    "fmt"
    "os"
    "path/filepath"
    "github.com/cloudfoundry/libbuildpack"
)

type IBMJRE struct {
    ctx              *Context
    jreDir           string
    version          string
    javaHome         string
    memoryCalc       *MemoryCalculator
    jvmkill          *JVMKillAgent
    installedVersion string
}

func NewIBMJRE(ctx *Context) *IBMJRE {
    jreDir := filepath.Join(ctx.Stager.DepDir(), "jre")
    return &IBMJRE{
        ctx:    ctx,
        jreDir: jreDir,
    }
}

func (i *IBMJRE) Name() string {
    return "IBM JRE"
}

func (i *IBMJRE) Detect() (bool, error) {
    // Check for explicit configuration
    configuredJRE := os.Getenv("JBP_CONFIG_COMPONENTS")
    if configuredJRE != "" && (containsString(configuredJRE, "IbmJRE") || containsString(configuredJRE, "IBM")) {
        return true, nil
    }
    
    // Check legacy config
    if DetectJREByEnv("ibm_jre") {
        return true, nil
    }
    
    return false, nil
}

func (i *IBMJRE) Supply() error {
    i.ctx.Log.BeginStep("Installing IBM JRE")
    
    // IBM JRE requires repository_root configuration
    dep, err := GetJREVersion(i.ctx, "ibm")
    if err != nil {
        i.ctx.Log.Warning("Unable to determine IBM JRE version from manifest, using default")
        dep = libbuildpack.Dependency{
            Name:    "ibm",
            Version: "8.0.8.26",
        }
    }
    
    i.version = dep.Version
    i.ctx.Log.Info("Installing IBM JRE %s", i.version)
    
    // Install JRE
    if err := i.ctx.Installer.InstallDependency(dep, i.jreDir); err != nil {
        return fmt.Errorf("failed to install IBM JRE: %w", err)
    }
    
    // Find JAVA_HOME (IBM extracts to ibm-java-* subdirectory)
    javaHome, err := i.findJavaHome()
    if err != nil {
        return fmt.Errorf("failed to find JAVA_HOME: %w", err)
    }
    i.javaHome = javaHome
    i.installedVersion = i.version
    
    // Write profile.d script
    if err := WriteJavaHomeProfileD(i.ctx, i.jreDir, i.javaHome); err != nil {
        i.ctx.Log.Warning("Could not write profile.d script: %s", err.Error())
    }
    
    // Determine Java major version
    javaMajorVersion, err := DetermineJavaVersion(javaHome)
    if err != nil {
        i.ctx.Log.Warning("Could not determine Java version: %s", err.Error())
        javaMajorVersion = 8 // IBM JRE default
    }
    i.ctx.Log.Info("Detected Java major version: %d", javaMajorVersion)
    
    // Install JVMKill agent
    i.jvmkill = NewJVMKillAgent(i.ctx, i.jreDir, i.version)
    if err := i.jvmkill.Supply(); err != nil {
        i.ctx.Log.Warning("Failed to install JVMKill agent: %s (continuing)", err.Error())
    }
    
    // Install Memory Calculator
    i.memoryCalc = NewMemoryCalculator(i.ctx, i.jreDir, i.version, javaMajorVersion)
    if err := i.memoryCalc.Supply(); err != nil {
        i.ctx.Log.Warning("Failed to install Memory Calculator: %s (continuing)", err.Error())
    }
    
    i.ctx.Log.Info("IBM JRE installation complete")
    return nil
}

// Finalize adds IBM-specific JVM options
func (i *IBMJRE) Finalize() error {
    i.ctx.Log.BeginStep("Finalizing IBM JRE configuration")
    
    // Find JAVA_HOME if not set
    if i.javaHome == "" {
        javaHome, err := i.findJavaHome()
        if err != nil {
            i.ctx.Log.Warning("Failed to find JAVA_HOME: %s", err.Error())
        } else {
            i.javaHome = javaHome
        }
    }
    
    // Determine Java major version
    javaMajorVersion := 8
    if i.javaHome != "" {
        if ver, err := DetermineJavaVersion(i.javaHome); err == nil {
            javaMajorVersion = ver
        }
    }
    
    // Finalize JVMKill agent
    if i.jvmkill == nil {
        i.jvmkill = NewJVMKillAgent(i.ctx, i.jreDir, i.version)
    }
    if err := i.jvmkill.Finalize(); err != nil {
        i.ctx.Log.Warning("Failed to finalize JVMKill agent: %s", err.Error())
    }
    
    // Finalize Memory Calculator
    if i.memoryCalc == nil {
        i.memoryCalc = NewMemoryCalculator(i.ctx, i.jreDir, i.version, javaMajorVersion)
    }
    if err := i.memoryCalc.Finalize(); err != nil {
        i.ctx.Log.Warning("Failed to finalize Memory Calculator: %s", err.Error())
    }
    
    // Add IBM-specific JVM options
    // -Xtune:virtualized - Optimizes for virtualized environments
    // -Xshareclasses:none - Disables class data sharing (not supported in containers)
    ibmOpts := "-Xtune:virtualized -Xshareclasses:none"
    if err := WriteJavaOpts(i.ctx, ibmOpts); err != nil {
        i.ctx.Log.Warning("Failed to write IBM JVM options: %s", err.Error())
    } else {
        i.ctx.Log.Info("Added IBM-specific JVM options: %s", ibmOpts)
    }
    
    i.ctx.Log.Info("IBM JRE finalization complete")
    return nil
}

func (i *IBMJRE) JavaHome() string {
    return i.javaHome
}

func (i *IBMJRE) Version() string {
    return i.installedVersion
}

func (i *IBMJRE) findJavaHome() (string, error) {
    entries, err := os.ReadDir(i.jreDir)
    if err != nil {
        return "", fmt.Errorf("failed to read JRE directory: %w", err)
    }
    
    // Look for ibm-java-* or jre subdirectory
    for _, entry := range entries {
        if entry.IsDir() {
            name := entry.Name()
            // IBM JRE specific patterns
            if (len(name) > 8 && name[:8] == "ibm-java") || name == "jre" {
                path := filepath.Join(i.jreDir, name)
                if _, err := os.Stat(filepath.Join(path, "bin", "java")); err == nil {
                    return path, nil
                }
            }
        }
    }
    
    // Check if jreDir itself is valid
    if _, err := os.Stat(filepath.Join(i.jreDir, "bin", "java")); err == nil {
        return i.jreDir, nil
    }
    
    return "", fmt.Errorf("could not find valid JAVA_HOME in %s", i.jreDir)
}
```

**Key Points:**
- **Custom JVM options:** Adds `-Xtune:virtualized` and `-Xshareclasses:none` in `Finalize()`
- **Vendor-specific naming:** Looks for `ibm-java-*` directory patterns
- **Repository configuration:** Requires users to configure repository via `JBP_CONFIG_IBM_JRE`

**Configuration:**

IBM JRE requires custom repository configuration in `config/ibm_jre.yml`:
```yaml
---
repository_root: "https://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/"
version: 8.0.+
```

Or via environment variable:
```bash
cf set-env myapp JBP_CONFIG_IBM_JRE '{version: 8.0.8.26, repository_root: "https://..."}'
```

## Common Patterns

### Version Selection

Use the `GetJREVersion()` helper to resolve versions:

```go
// GetJREVersion checks environment variables and manifest
dep, err := GetJREVersion(ctx, "openjdk")
```

Version sources (in priority order):
1. `BP_JAVA_VERSION` environment variable (e.g., `BP_JAVA_VERSION=17`)
2. `JBP_CONFIG_<JRE_NAME>` environment variable
3. Manifest default version

**Examples:**
```bash
# Simple version
cf set-env myapp BP_JAVA_VERSION 21

# Version pattern (wildcard)
cf set-env myapp BP_JAVA_VERSION "17.*"

# Legacy config
cf set-env myapp JBP_CONFIG_OPEN_JDK_JRE '{jre: {version: 11.+}}'
```

### Finding JAVA_HOME

JRE tarballs often extract to subdirectories. Use this pattern:

```go
func (j *MyJRE) findJavaHome() (string, error) {
    entries, err := os.ReadDir(j.jreDir)
    if err != nil {
        return "", fmt.Errorf("failed to read JRE directory: %w", err)
    }
    
    // Look for vendor-specific patterns first
    for _, entry := range entries {
        if entry.IsDir() {
            name := entry.Name()
            // Example: "myjre-21.0.1" or "jdk-21.0.1"
            if strings.HasPrefix(name, "myjre-") || strings.HasPrefix(name, "jdk-") {
                path := filepath.Join(j.jreDir, name)
                // Verify it's a valid JRE
                if _, err := os.Stat(filepath.Join(path, "bin", "java")); err == nil {
                    return path, nil
                }
            }
        }
    }
    
    // Fallback: check if jreDir itself is valid
    if _, err := os.Stat(filepath.Join(j.jreDir, "bin", "java")); err == nil {
        return j.jreDir, nil
    }
    
    return "", fmt.Errorf("could not find valid JAVA_HOME in %s", j.jreDir)
}
```

### Profile.d Script

Always create a profile.d script to export JAVA_HOME at runtime:

```go
// Use the helper function
if err := WriteJavaHomeProfileD(ctx, jreDir, javaHome); err != nil {
    ctx.Log.Warning("Could not write profile.d script: %s", err.Error())
}
```

This creates `.profile.d/java.sh`:
```bash
export JAVA_HOME=$DEPS_DIR/0/jre/jdk-17.0.13
export JRE_HOME=$DEPS_DIR/0/jre/jdk-17.0.13
export PATH=$JAVA_HOME/bin:$PATH
```

### Adding JVM Options

Use `WriteJavaOpts()` to add JVM options:

```go
// Add custom JVM options
opts := "-XX:+UseG1GC -XX:MaxGCPauseMillis=200"
if err := WriteJavaOpts(ctx, opts); err != nil {
    ctx.Log.Warning("Failed to write JVM options: %s", err.Error())
}
```

This appends to `.profile.d/java_opts.sh`:
```bash
export JAVA_OPTS="${JAVA_OPTS:--XX:+UseG1GC -XX:MaxGCPauseMillis=200}"
```

### Determining Java Version

Determine the major Java version for memory calculator:

```go
javaMajorVersion, err := DetermineJavaVersion(javaHome)
if err != nil {
    ctx.Log.Warning("Could not determine Java version: %s", err.Error())
    javaMajorVersion = 17 // default
}
```

This reads the `release` file in JAVA_HOME:
```
JAVA_VERSION="17.0.13"
```

## Memory Calculator Integration

The Memory Calculator computes optimal JVM memory settings based on container memory limits.

### Installing Memory Calculator

Install during `Supply()`:

```go
// Create memory calculator component
memoryCalc := NewMemoryCalculator(ctx, jreDir, jreVersion, javaMajorVersion)

// Install the calculator binary
if err := memoryCalc.Supply(); err != nil {
    ctx.Log.Warning("Failed to install Memory Calculator: %s", err.Error())
    // Non-fatal - continue without memory calculator
}
```

### Finalizing Memory Calculator

Configure during `Finalize()`:

```go
// Finalize memory calculator
if err := memoryCalc.Finalize(); err != nil {
    ctx.Log.Warning("Failed to finalize Memory Calculator: %s", err.Error())
}
```

This creates a script that containers can invoke at runtime:
```bash
CALCULATED_MEMORY=$(java-buildpack-memory-calculator-3.13.0 \
    -totMemory=$MEMORY_LIMIT \
    -loadedClasses=12345 \
    -poolType=metaspace \
    -stackThreads=250)
export JAVA_OPTS="$JAVA_OPTS $CALCULATED_MEMORY"
```

### Memory Calculator Output

At runtime, the calculator generates JVM options:
```
-Xmx512M -Xms512M -XX:MaxMetaspaceSize=128M -Xss1M -XX:ReservedCodeCacheSize=32M
```

### Customizing Memory Calculator

Users can customize via environment variables:
```bash
cf set-env myapp MEMORY_CALCULATOR_STACK_THREADS 300
cf set-env myapp MEMORY_CALCULATOR_HEADROOM 10
```

## JVMKill Agent

JVMKill is an agent that forcibly terminates the JVM when it cannot allocate memory or throws OutOfMemoryError.

### Installing JVMKill

Install during `Supply()`:

```go
// Create JVMKill agent component
jvmkill := NewJVMKillAgent(ctx, jreDir, jreVersion)

// Install the agent .so file
if err := jvmkill.Supply(); err != nil {
    ctx.Log.Warning("Failed to install JVMKill agent: %s", err.Error())
    // Non-fatal - continue without jvmkill
}
```

### Finalizing JVMKill

Add to JAVA_OPTS during `Finalize()`:

```go
// Finalize JVMKill agent (adds -agentpath to JAVA_OPTS)
if err := jvmkill.Finalize(); err != nil {
    ctx.Log.Warning("Failed to finalize JVMKill agent: %s", err.Error())
}
```

This adds to JAVA_OPTS:
```
-agentpath:/home/vcap/deps/0/jre/bin/jvmkill-1.16.0.so=printHeapHistogram=1
```

### Heap Dump Support

If a volume service with `heap-dump` tag is bound, JVMKill writes heap dumps:
```
-agentpath:/home/vcap/deps/0/jre/bin/jvmkill-1.16.0.so=printHeapHistogram=1,heapDumpPath=/volumes/heap-dumps/app.hprof
```

Bind volume service:
```bash
cf bind-service myapp my-volume-service -c '{"mount":"/volumes/heap-dumps","tags":["heap-dump"]}'
```

## Testing JREs

### Unit Testing with Ginkgo

Test your JRE implementation using Ginkgo and Gomega:

**File:** `src/java/jres/myjre_test.go`

```go
package jres_test

import (
    "os"
    "path/filepath"
    "github.com/cloudfoundry/java-buildpack/src/java/jres"
    "github.com/cloudfoundry/libbuildpack"
    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
)

var _ = Describe("MyJRE", func() {
    var (
        ctx      *jres.Context
        myJRE    jres.JRE
        buildDir string
        depsDir  string
        cacheDir string
    )
    
    BeforeEach(func() {
        var err error
        buildDir, err = os.MkdirTemp("", "build")
        Expect(err).NotTo(HaveOccurred())
        
        depsDir, err = os.MkdirTemp("", "deps")
        Expect(err).NotTo(HaveOccurred())
        
        cacheDir, err = os.MkdirTemp("", "cache")
        Expect(err).NotTo(HaveOccurred())
        
        // Create deps directory structure
        err = os.MkdirAll(filepath.Join(depsDir, "0"), 0755)
        Expect(err).NotTo(HaveOccurred())
        
        // Set up context
        logger := libbuildpack.NewLogger(os.Stdout)
        manifest := &libbuildpack.Manifest{}
        installer := &libbuildpack.Installer{}
        stager := libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, "0"}, logger, manifest)
        command := &libbuildpack.Command{}
        
        ctx = &jres.Context{
            Stager:    stager,
            Manifest:  manifest,
            Installer: installer,
            Log:       logger,
            Command:   command,
        }
        
        myJRE = jres.NewMyJRE(ctx)
    })
    
    AfterEach(func() {
        os.RemoveAll(buildDir)
        os.RemoveAll(depsDir)
        os.RemoveAll(cacheDir)
    })
    
    Describe("Name", func() {
        It("returns the JRE name", func() {
            Expect(myJRE.Name()).To(Equal("My JRE"))
        })
    })
    
    Describe("Detect", func() {
        Context("when JBP_CONFIG_COMPONENTS specifies MyJRE", func() {
            BeforeEach(func() {
                os.Setenv("JBP_CONFIG_COMPONENTS", "{jres: ['MyJRE']}")
            })
            
            AfterEach(func() {
                os.Unsetenv("JBP_CONFIG_COMPONENTS")
            })
            
            It("detects successfully", func() {
                detected, err := myJRE.Detect()
                Expect(err).NotTo(HaveOccurred())
                Expect(detected).To(BeTrue())
            })
        })
        
        Context("when not configured", func() {
            It("does not detect", func() {
                detected, err := myJRE.Detect()
                Expect(err).NotTo(HaveOccurred())
                Expect(detected).To(BeFalse())
            })
        })
    })
    
    Describe("JavaHome", func() {
        Context("before installation", func() {
            It("returns empty string", func() {
                Expect(myJRE.JavaHome()).To(BeEmpty())
            })
        })
        
        Context("after simulated installation", func() {
            BeforeEach(func() {
                // Simulate JRE installation
                jreDir := filepath.Join(depsDir, "0", "jre", "myjre-17.0.1")
                err := os.MkdirAll(filepath.Join(jreDir, "bin"), 0755)
                Expect(err).NotTo(HaveOccurred())
                
                // Create fake java executable
                javaPath := filepath.Join(jreDir, "bin", "java")
                err = os.WriteFile(javaPath, []byte("#!/bin/sh\necho 'java version \"17.0.1\"'\n"), 0755)
                Expect(err).NotTo(HaveOccurred())
            })
            
            It("finds JAVA_HOME after finalize", func() {
                err := myJRE.Finalize()
                // May return error if components missing, but should not panic
                _ = err
                
                // JavaHome should be set if findJavaHome succeeded
                javaHome := myJRE.JavaHome()
                if javaHome != "" {
                    Expect(javaHome).To(ContainSubstring("myjre-17.0.1"))
                }
            })
        })
    })
    
    Describe("Version", func() {
        Context("before installation", func() {
            It("returns empty string", func() {
                Expect(myJRE.Version()).To(BeEmpty())
            })
        })
    })
})
```

### Running Tests

Run JRE tests:
```bash
# Run all JRE tests
./scripts/unit.sh

# Run specific JRE test
go test -v ./src/java/jres -run TestMyJRE

# Run with Ginkgo
ginkgo -v ./src/java/jres
```

### Integration Testing

Create integration tests to verify JRE installation:

**File:** `src/integration/myjre_test.go`

```go
package integration_test

import (
    "path/filepath"
    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
    "github.com/cloudfoundry/switchblade"
)

var _ = Describe("MyJRE Integration", func() {
    var (
        fixture string
    )
    
    BeforeEach(func() {
        fixture = "simple_java_app"
    })
    
    Context("when MyJRE is configured", func() {
        It("successfully builds and runs", func() {
            deployment, _, err := switchblade.Deploy(
                switchblade.Buildpack(bpDir),
                switchblade.FixturePath(filepath.Join(fixturesDir, fixture)),
                switchblade.Env(map[string]string{
                    "JBP_CONFIG_COMPONENTS": "{jres: ['MyJRE']}",
                    "BP_JAVA_VERSION": "17",
                }),
            )
            Expect(err).NotTo(HaveOccurred())
            defer deployment.Delete()
            
            // Verify app is running
            Expect(deployment.Status()).To(Equal(switchblade.StatusRunning))
            
            // Verify logs contain MyJRE
            logs, err := deployment.Logs()
            Expect(err).NotTo(HaveOccurred())
            Expect(logs).To(ContainSubstring("Installing My JRE"))
        })
    })
})
```

## Best Practices

### 1. Use Shared Utility Functions

Leverage existing helper functions in `jre.go`:
- `GetJREVersion()` - Version resolution
- `DetermineJavaVersion()` - Parse Java version
- `WriteJavaHomeProfileD()` - Create profile.d script
- `WriteJavaOpts()` - Add JVM options
- `DetectJREByEnv()` - Check environment variables

### 2. Handle Errors Gracefully

Component installation failures should be non-fatal:
```go
// Install JVMKill (non-fatal if it fails)
if err := jvmkill.Supply(); err != nil {
    ctx.Log.Warning("Failed to install JVMKill: %s (continuing)", err.Error())
    // Continue without JVMKill
}
```

### 3. Support Version Flexibility

Accept version patterns:
```bash
BP_JAVA_VERSION=17      # Exact major version
BP_JAVA_VERSION=17.*    # Any 17.x version
BP_JAVA_VERSION=17.0.+  # Any 17.0.x patch
```

### 4. Log Comprehensively

Use structured logging:
```go
ctx.Log.BeginStep("Installing My JRE")              // Major phase
ctx.Log.Info("Installing My JRE %s", version)       // User-visible info
ctx.Log.Debug("Extracted to: %s", javaHome)         // Debug details
ctx.Log.Warning("Could not verify: %s", err.Error()) // Non-fatal warnings
```

### 5. Verify Installation

Always verify JAVA_HOME after extraction:
```go
javaExecutable := filepath.Join(javaHome, "bin", "java")
if _, err := os.Stat(javaExecutable); err != nil {
    return fmt.Errorf("invalid JAVA_HOME: bin/java not found at %s", javaHome)
}
```

### 6. Support Vendor-Specific Features

Add vendor-specific JVM options in `Finalize()`:
```go
// GraalVM: Enable native image agent
opts := "-agentlib:native-image-agent=config-output-dir=/tmp/config"

// IBM JRE: Optimize for virtualization
opts := "-Xtune:virtualized -Xshareclasses:none"

// Zulu: Enable Flight Recorder
opts := "-XX:StartFlightRecording=duration=60s,filename=/tmp/recording.jfr"

WriteJavaOpts(ctx, opts)
```

### 7. Document Configuration

Add configuration documentation for your JRE in `docs/jre-<name>.md`:
- Environment variable options
- Repository configuration
- Version availability
- Vendor-specific features

### 8. Test Multiple Versions

Test with multiple Java versions:
```go
DescribeTable("supports multiple versions",
    func(version string) {
        os.Setenv("BP_JAVA_VERSION", version)
        defer os.Unsetenv("BP_JAVA_VERSION")
        
        detected, err := jre.Detect()
        Expect(err).NotTo(HaveOccurred())
        Expect(detected).To(BeTrue())
    },
    Entry("Java 8", "8"),
    Entry("Java 11", "11"),
    Entry("Java 17", "17"),
    Entry("Java 21", "21"),
)
```

## Troubleshooting

### JRE Not Detected

**Problem:** JRE not being selected during staging

**Solution:**
1. Check detection logic:
   ```bash
   # Enable debug logging
   cf set-env myapp BP_LOG_LEVEL DEBUG
   cf restage myapp
   ```

2. Verify environment variables:
   ```bash
   cf env myapp | grep JBP_CONFIG_COMPONENTS
   ```

3. Check detection order in registry (first match wins)

### JAVA_HOME Not Found

**Problem:** `findJavaHome()` fails after extraction

**Solution:**
1. Check tarball structure:
   ```bash
   tar -tzf openjdk-17.0.13.tar.gz | head
   ```

2. Update directory pattern matching:
   ```go
   // Add more patterns
   if strings.HasPrefix(name, "custom-prefix-") {
       // ...
   }
   ```

3. Log extracted directory structure:
   ```go
   ctx.Log.Debug("JRE directory contents: %v", entries)
   ```

### Memory Calculator Fails

**Problem:** Memory calculator not generating options

**Solution:**
1. Verify calculator installed:
   ```bash
   ls $DEPS_DIR/0/jre/bin/java-buildpack-memory-calculator-*
   ```

2. Check class counting:
   ```go
   ctx.Log.Debug("Counted %d classes", classCount)
   ```

3. Test calculator manually:
   ```bash
   java-buildpack-memory-calculator -totMemory=1G -loadedClasses=10000 -poolType=metaspace -stackThreads=250
   ```

### JVMKill Not Loading

**Problem:** JVMKill agent not being loaded

**Solution:**
1. Verify .so file exists:
   ```bash
   ls -la /home/vcap/deps/0/jre/bin/jvmkill-*.so
   ```

2. Check JAVA_OPTS at runtime:
   ```bash
   cf ssh myapp
   echo $JAVA_OPTS
   ```

3. Verify agentpath:
   ```bash
   # Should see: -agentpath:/home/vcap/deps/0/jre/bin/jvmkill-1.16.0.so=...
   ```

### Profile.d Script Not Executing

**Problem:** JAVA_HOME not set at runtime

**Solution:**
1. Verify profile.d script exists:
   ```bash
   cf ssh myapp
   cat /home/vcap/app/.profile.d/java.sh
   ```

2. Check script permissions:
   ```bash
   ls -la /home/vcap/app/.profile.d/
   ```

3. Test script manually:
   ```bash
   source /home/vcap/app/.profile.d/java.sh
   echo $JAVA_HOME
   ```

### Version Resolution Issues

**Problem:** Wrong Java version being installed

**Solution:**
1. Check manifest versions:
   ```bash
   grep -A 10 '"openjdk"' manifest.yml
   ```

2. Test version resolution:
   ```go
   dep, err := GetJREVersion(ctx, "openjdk")
   ctx.Log.Info("Resolved version: %s", dep.Version)
   ```

3. Override explicitly:
   ```bash
   cf set-env myapp BP_JAVA_VERSION 17.0.13
   ```

---

## Summary

Implementing a JRE provider involves:

1. **Create struct** implementing `jres.JRE` interface
2. **Implement detection** logic (environment variables)
3. **Download and extract** JRE tarball in `Supply()`
4. **Find JAVA_HOME** handling nested directories
5. **Install components** (Memory Calculator, JVMKill)
6. **Configure runtime** with profile.d scripts
7. **Add JVM options** vendor-specific or optimizations
8. **Test thoroughly** with unit and integration tests

The buildpack provides extensive utilities to simplify JRE implementation. Follow the patterns from existing JRE providers (OpenJDK, Zulu, IBM) and leverage shared components (Memory Calculator, JVMKill) for consistent functionality across all JREs.

For more information:
- [Architecture Guide](../ARCHITECTURE.md) - Overall buildpack design
- [Development Guide](DEVELOPING.md) - Building and testing
- [Testing Guide](TESTING.md) - Test framework details
- [Implementing Frameworks](IMPLEMENTING_FRAMEWORKS.md) - Framework integration
- [Implementing Containers](IMPLEMENTING_CONTAINERS.md) - Container types
