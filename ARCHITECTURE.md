# Cloud Foundry Java Buildpack - Go Implementation Architecture

**Last Updated**: December 13, 2025  
**Migration Status**: Complete (Ruby → Go)

---

## Table of Contents

1. [Overview](#overview)
2. [Directory Structure](#directory-structure)
3. [Component Types](#component-types)
4. [Buildpack Lifecycle](#buildpack-lifecycle)
5. [Key Architectural Patterns](#key-architectural-patterns)
6. [Component Interface](#component-interface)
7. [Configuration System](#configuration-system)
8. [Dependency Management](#dependency-management)
9. [Cloud Foundry Integration](#cloud-foundry-integration)

---

## Overview

The Cloud Foundry Java Buildpack is implemented in Go and follows Cloud Foundry's V3 buildpack API. The buildpack is responsible for:

1. **Detecting** if an application is a Java application
2. **Supplying** dependencies (JRE, frameworks, libraries) during staging
3. **Finalizing** runtime configuration and generating the launch command

### Architecture Principles

- **Modularity**: Components are independent and composable
- **Convention over Configuration**: Sensible defaults with override capability
- **Declarative Configuration**: YAML-based configuration system
- **Lifecycle Separation**: Clear separation between staging and runtime phases

---

## Directory Structure

```
java-buildpack/
├── bin/
│   ├── compile           # Legacy V2 API entrypoint
│   ├── detect            # Detection phase entrypoint
│   ├── finalize          # Finalize phase entrypoint (V3)
│   └── supply            # Supply phase entrypoint (V3)
│
├── config/               # Component configurations
│   ├── components.yml    # Component registry
│   ├── cache.yml         # Caching configuration
│   ├── repository.yml    # Dependency repository config
│   └── *.yml             # Individual component configs
│
├── resources/            # Static resources for components
│   ├── tomcat/           # Tomcat configuration templates
│   ├── protect_app_security_provider/
│   └── ...
│
├── src/java/             # Go source code
│   ├── containers/       # Container implementations
│   ├── frameworks/       # Framework implementations
│   ├── jres/             # JRE implementations
│   ├── supply/           # Supply phase orchestration
│   │   └── cli/          # Supply CLI entrypoint
│   └── finalize/         # Finalize phase orchestration
│       └── cli/          # Finalize CLI entrypoint
│
├── docs/                 # Documentation
└── scripts/              # Build and test scripts
```

---

## Component Types

The buildpack uses three main component types:

### 1. Containers

**Purpose**: Define how the application will be executed

**Responsibilities**:
- Detect application type (Spring Boot, Tomcat, Groovy, etc.)
- Download and configure the container/runtime
- Generate the launch command

**Examples**:
- `spring_boot.go` - Spring Boot embedded server detection
- `tomcat.go` - Traditional WAR file deployment
- `java_main.go` - Simple Java main class execution
- `groovy.go` - Groovy script execution

**Location**: `src/java/containers/`

**Selection**: Only ONE container can be selected per application

### 2. Frameworks

**Purpose**: Add additional capabilities and transformations

**Responsibilities**:
- Detect required frameworks (via service bindings, files, etc.)
- Download and install agents, libraries, transformers
- Configure Java options, environment variables
- Generate profile.d scripts for runtime setup

**Examples**:
- `new_relic.go` - New Relic APM agent
- `java_cf_env.go` - Cloud Foundry environment integration
- `postgresql_jdbc.go` - PostgreSQL JDBC driver injection
- `jmx.go` - JMX remote access configuration

**Location**: `src/java/frameworks/`

**Selection**: MULTIPLE frameworks can be active simultaneously

### 3. JREs (Java Runtime Environments)

**Purpose**: Provide the Java runtime for the application

**Responsibilities**:
- Detect required JRE version
- Download and install the JRE
- Configure memory settings (via memory calculator)
- Install JVM utilities (jvmkill agent)

**Examples**:
- `openjdk.go` - OpenJDK JRE (default)
- `zulu.go` - Azul Zulu JRE
- `graalvm.go` - GraalVM
- `sapmachine.go` - SAP Machine JRE

**Location**: `src/java/jres/`

**Selection**: Only ONE JRE can be selected per application

---

## Buildpack Lifecycle

The buildpack follows Cloud Foundry's V3 lifecycle with three phases:

### 1. Detect Phase

**Purpose**: Determine if this buildpack can run the application

**Entry Point**: `bin/detect`

**Flow**:
```
1. Check for Java application indicators:
   - .jar files
   - .war files  
   - Main-Class in MANIFEST.MF
   - Spring Boot markers
   - Groovy scripts
   - etc.

2. If Java app detected → Exit 0 (success)
3. If not → Exit 1 (failure)
```

**Output**: Tags printed to stdout (e.g., `open-jdk-jre=17.0.1`)

### 2. Supply Phase

**Purpose**: Download and install all dependencies

**Entry Point**: `bin/supply` → `src/java/supply/cli/main.go`

**Flow**:
```
1. Load component registry (config/components.yml)
2. For each component type (JRE, Frameworks):
   a. Run Detect() method
   b. If detected, run Supply() method
   
3. Supply() responsibilities:
   - Download dependencies from repositories
   - Extract/install to deps directory
   - Copy resources
   - NO runtime configuration yet

4. Output dependencies to:
   <deps_dir>/<deps_idx>/
```

**Key Characteristics**:
- Can be run multiple times (multi-buildpack)
- Modifies staging environment only
- Downloads from internet/repositories
- No profile.d generation here

### 3. Finalize Phase

**Purpose**: Configure runtime environment and generate launch command

**Entry Point**: `bin/finalize` → `src/java/finalize/cli/main.go`

**Flow**:
```
1. Load all detected components
2. Select ONE container
3. For each component (Container, Frameworks, JRE):
   a. Run Finalize() method
   
4. Finalize() responsibilities:
   - Write profile.d scripts
   - Set environment variables
   - Configure JAVA_OPTS
   - Container generates launch command

5. Output:
   - profile.d/*.sh scripts
   - launch command (returned by container)
```

**Key Characteristics**:
- Runs once (last buildpack only)
- No internet access
- Generates runtime configuration
- Profile.d scripts run before app launch

---

## Key Architectural Patterns

### 1. Context Pattern

Every component receives a `Context` struct containing:

```go
type Context struct {
    Stager      *Stager       // Build directory, deps directory access
    Manifest    *Manifest     // Dependency version resolution
    Installer   *Installer    // Dependency download/install
    Log         *Logger       // Structured logging
    // ... other utilities
}
```

**Usage**:
```go
func (f *MyFramework) Supply() error {
    // Access build directory
    buildDir := f.context.Stager.BuildDir()
    
    // Get dependency version
    dep, err := f.context.Manifest.DefaultVersion("my-framework")
    
    // Install dependency
    targetDir := filepath.Join(f.context.Stager.DepDir(), "my_framework")
    err = f.context.Installer.InstallDependency(dep, targetDir)
    
    return nil
}
```

### 2. Component Interface Pattern

All components implement a consistent interface:

```go
type Component interface {
    // Detect returns non-empty string if component applies
    Detect() (string, error)
    
    // Supply installs dependencies (staging phase)
    Supply() error
    
    // Finalize configures runtime (finalize phase)
    Finalize() error
}
```

### 3. Profile.d Script Pattern

Runtime configuration is done via profile.d scripts:

```go
func (f *MyFramework) Finalize() error {
    script := `#!/bin/bash
export MY_VAR="value"
export JAVA_OPTS="${JAVA_OPTS} -Dmy.property=value"
`
    return f.context.Stager.WriteProfileD("my_framework.sh", script)
}
```

**Scripts execute**: Before app launch, in lexicographic order

### 4. VCAP_SERVICES Detection Pattern

Many frameworks detect via service bindings:

```go
func (f *MyFramework) findService() (map[string]interface{}, error) {
    vcapServices := os.Getenv("VCAP_SERVICES")
    var services map[string][]map[string]interface{}
    json.Unmarshal([]byte(vcapServices), &services)
    
    // Search for service by name/label/tag
    for _, serviceList := range services {
        for _, service := range serviceList {
            if matchesPattern(service) {
                return service, nil
            }
        }
    }
    return nil, errors.New("service not found")
}
```

### 5. Manifest-Based Dependency Pattern

Dependencies are resolved via buildpack manifest:

```go
// Get default version from manifest
dep, err := f.context.Manifest.DefaultVersion("tomcat")
// Returns: Dependency{Name: "tomcat", Version: "9.0.54", URI: "https://..."}

// Install to target directory
err = f.context.Installer.InstallDependency(dep, targetDir)
```

---

## Component Interface

### Detect Method

**Signature**: `Detect() (string, error)`

**Purpose**: Determine if component should be included

**Return Values**:
- Non-empty string: Component detected (string is used as tag)
- Empty string: Component not applicable
- Error: Detection failed

**Example**:
```go
func (f *NewRelicFramework) Detect() (string, error) {
    // Check for bound New Relic service
    service, err := f.findNewRelicService()
    if err != nil {
        return "", nil  // Not detected, not an error
    }
    
    // Get version
    dep, _ := f.context.Manifest.DefaultVersion("new-relic")
    
    return fmt.Sprintf("new-relic-agent=%s", dep.Version), nil
}
```

### Supply Method

**Signature**: `Supply() error`

**Purpose**: Download and install dependencies

**Responsibilities**:
- Download from internet/repositories
- Extract archives
- Copy files to deps directory
- Prepare for finalize phase

**Constraints**:
- Must be idempotent
- No runtime configuration
- No profile.d scripts

**Example**:
```go
func (f *NewRelicFramework) Supply() error {
    f.context.Log.BeginStep("Installing New Relic Agent")
    
    // Get dependency from manifest
    dep, err := f.context.Manifest.DefaultVersion("new-relic")
    if err != nil {
        return fmt.Errorf("unable to determine version: %w", err)
    }
    
    // Install to deps directory
    targetDir := filepath.Join(f.context.Stager.DepDir(), "new_relic")
    if err := f.context.Installer.InstallDependency(dep, targetDir); err != nil {
        return fmt.Errorf("failed to install: %w", err)
    }
    
    f.context.Log.Info("Installed New Relic Agent %s", dep.Version)
    return nil
}
```

### Finalize Method

**Signature**: `Finalize() error`

**Purpose**: Configure runtime environment

**Responsibilities**:
- Write profile.d scripts
- Set environment variables
- Configure JAVA_OPTS
- Generate launch command (containers only)

**Constraints**:
- No internet access
- Uses files from supply phase
- Must be fast (impacts staging time)

**Example**:
```go
func (f *NewRelicFramework) Finalize() error {
    // Find installed agent JAR
    agentDir := filepath.Join(f.context.Stager.DepDir(), "new_relic")
    agentJar := filepath.Join(agentDir, "newrelic.jar")
    
    // Get license key from service binding
    service, _ := f.findNewRelicService()
    creds := service["credentials"].(map[string]interface{})
    licenseKey := creds["license_key"].(string)
    
    // Create profile.d script
    script := fmt.Sprintf(`#!/bin/bash
export JAVA_OPTS="${JAVA_OPTS} -javaagent:%s"
export JAVA_OPTS="${JAVA_OPTS} -Dnewrelic.config.license_key=%s"
`, agentJar, licenseKey)
    
    return f.context.Stager.WriteProfileD("new_relic.sh", script)
}
```

---

## Configuration System

### Component Registry

**File**: `config/components.yml`

**Purpose**: Declare available components

**Structure**:
```yaml
containers:
  - "JavaBuildpack::Container::SpringBoot"
  - "JavaBuildpack::Container::Tomcat"
  # ...

jres:
  - "JavaBuildpack::Jre::OpenJdkJRE"
  # ...

frameworks:
  - "JavaBuildpack::Framework::NewRelicAgent"
  - "JavaBuildpack::Framework::JavaOpts"
  # ...
```

### Component Configuration

**Pattern**: `config/<component_name>.yml`

**Purpose**: Configure individual components

**Example** (`config/new_relic_agent.yml`):
```yaml
version: 8.7.+
repository_root: https://download.run.pivotal.io/new-relic
enabled: true
```

### Environment Variable Overrides

Users can override configuration via environment variables:

**Operator-level** (foundation-wide):
```bash
JBP_DEFAULT_OPEN_JDK_JRE='{ jre: { version: 17.+ } }'
```

**Application-level**:
```bash
cf set-env my-app JBP_CONFIG_OPEN_JDK_JRE '{ jre: { version: 11.+ } }'
```

---

## Dependency Management

### Buildpack Manifest

**File**: `manifest.yml` (generated during packaging)

**Purpose**: Declare available dependencies and their locations

**Structure**:
```yaml
dependencies:
  - name: openjdk
    version: 17.0.5
    uri: https://github.com/adoptium/temurin17-binaries/.../OpenJDK17.tar.gz
    sha256: abc123...
    stacks:
      - cflinuxfs4
```

### Dependency Resolution

1. Component requests dependency: `Manifest.DefaultVersion("openjdk")`
2. Manifest finds matching version (version ranges supported)
3. Returns `Dependency` struct with URI and metadata
4. Installer downloads and verifies (checksum)
5. Installer extracts to target directory

### Version Syntax

Supports semantic versioning with wildcards:

- `17.+` - Latest 17.x version
- `11.0.+` - Latest 11.0.x version
- `8.+` - Latest 8.x version

---

## Cloud Foundry Integration

### Environment Variables

The buildpack uses CF environment variables:

- `VCAP_SERVICES` - Service binding information
- `VCAP_APPLICATION` - Application metadata
- `CF_STACK` - Stack name (cflinuxfs4, etc.)
- `BP_*` - Buildpack configuration variables

### Service Binding Pattern

Frameworks detect services via `VCAP_SERVICES`:

```json
{
  "postgresql": [{
    "name": "my-db",
    "credentials": {
      "uri": "postgres://...",
      "username": "user",
      "password": "pass"
    }
  }]
}
```

### Profile.d Scripts

Scripts in `<app>/.profile.d/` run before app launch:

```bash
# Execution order
1. System profile.d scripts
2. Buildpack profile.d scripts (alphabetical)
3. Application launch command
```

---

## Component Execution Order

### Supply Phase Order

1. **JREs** - Install Java runtime first
2. **Frameworks** - Process in `components.yml` order

### Finalize Phase Order

1. **JRE** - Configure Java runtime
2. **Frameworks** - Process in `components.yml` order  
3. **Container** - Generate launch command (last)

**Important**: `JavaOpts` framework must be last to allow user overrides

---

## Development Workflow

See [DEVELOPING.md](docs/DEVELOPING.md) for detailed development instructions.

**Quick Start**:
```bash
# Build
./scripts/build.sh

# Run tests
./scripts/unit.sh
./scripts/integration.sh

# Package
./scripts/package.sh
```

---

## Further Reading

- [DEVELOPING.md](docs/DEVELOPING.md) - Development setup and workflow
- [IMPLEMENTING_FRAMEWORKS.md](docs/IMPLEMENTING_FRAMEWORKS.md) - Framework implementation guide
- [IMPLEMENTING_CONTAINERS.md](docs/IMPLEMENTING_CONTAINERS.md) - Container implementation guide
- [IMPLEMENTING_JRES.md](docs/IMPLEMENTING_JRES.md) - JRE implementation guide
- [TESTING.md](docs/TESTING.md) - Testing guide
- [design.md](docs/design.md) - High-level design overview

---

## Migration Notes

This buildpack was migrated from Ruby to Go in 2025. Key differences:

| Aspect | Ruby Buildpack | Go Buildpack |
|--------|---------------|--------------|
| **Language** | Ruby | Go |
| **API Version** | V2 (compile/release) | V3 (supply/finalize) |
| **Base Classes** | BaseComponent, ModularComponent | Interface-based |
| **Configuration** | Ruby DSL | YAML + env vars |
| **Lifecycle** | detect→compile→release | detect→supply→finalize |
| **Multi-buildpack** | Via framework | Native CF support |

---

**Questions or issues?** See [CONTRIBUTING.md](CONTRIBUTING.md) for how to get help.
