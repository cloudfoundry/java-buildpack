# Design

The Cloud Foundry Java Buildpack is designed as a collection of components. These components are divided into three types: **Containers**, **Frameworks**, and **JREs**. The buildpack is implemented in Go and follows Cloud Foundry buildpack conventions.

## Architecture Overview

The buildpack operates in two phases:

1. **Supply Phase** (`bin/supply`): Detects components, downloads dependencies, and prepares the application
2. **Finalize Phase** (`bin/finalize`): Configures runtime settings and generates the launch command

Each component type implements a common interface and is processed in a specific order during these phases.

## Container Components

Container components represent the way that an application will be run. Container types range from traditional application servers and servlet containers to simple Java `main()` method execution.

**Responsibilities:**
- Detect which container should be used based on application structure
- Download and install the container runtime (e.g., Tomcat, Jetty)
- Transform the application as needed (e.g., extract JARs, configure servers)
- Generate the command that will be executed by Cloud Foundry at runtime

**Implementation:**
Container components implement the `Container` interface defined in `src/java/containers/container.go`:

```go
type Container interface {
    Detect() (string, error)  // Returns container name if detected, empty string otherwise
    Supply() error
    Finalize() error
    Release() (string, error)
}
```

**Container Types:**
- **Dist Zip**: Distributable archives (ZIP, TAR.GZ) with startup scripts
- **Groovy**: Standalone Groovy scripts
- **Java Main**: Executable JARs with `Main-Class` manifest entry
- **Play Framework**: Play 2.x applications
- **Spring Boot**: Spring Boot executable JARs
- **Spring Boot CLI**: Spring Boot CLI applications
- **Tomcat**: WAR files deployed to Tomcat

**Detection Order:**
Only a single container component can run an application. Containers are detected in priority order (most specific to least specific):
1. Spring Boot
2. Spring Boot CLI
3. Tomcat
4. Groovy
5. Play Framework
6. Dist Zip
7. Java Main

If more than one container matches, the first one wins. If no container can be used, an error will be raised and application staging will fail.

**See Also:**
- [Implementing Containers Guide](IMPLEMENTING_CONTAINERS.md) - Detailed implementation instructions
- [Container Documentation](container-*.md) - Individual container guides

## Framework Components

Framework components represent additional behavior or transformations used when an application is run. Framework types include monitoring agents (New Relic, AppDynamics), security providers (Luna, Contrast), JDBC JARs for bound services, and automatic Spring reconfiguration.

**Responsibilities:**
- Detect when the framework is required (via environment variables or bound services)
- Download and install framework components (agents, libraries)
- Transform the application (inject dependencies, modify configuration)
- Contribute JVM options (e.g., `-javaagent`, system properties)

**Implementation:**
Framework components implement the `Framework` interface defined in `src/java/frameworks/framework.go`:

```go
type Framework interface {
    Detect() (string, error)  // Returns framework name if detected, empty string otherwise
    Supply() error
    Finalize() error
}
```

**Framework Categories:**
- **Monitoring Agents**: AppDynamics, New Relic, Dynatrace, Elastic APM
- **Security Providers**: Luna, Contrast, Seeker, Protect App
- **Profilers**: JProfiler, YourKit
- **JDBC Drivers**: PostgreSQL, MariaDB
- **Spring Utilities**: Auto-reconfiguration, Cloud Connectors
- **Debugging Tools**: Debug, JMX, JaCoCo

**Detection:**
Any number of framework components can be used when running an application. Frameworks detect independently based on:
- Environment variables (e.g., `JBP_CONFIG_NEW_RELIC_AGENT`)
- Bound services (e.g., VCAP_SERVICES with specific tags)
- Application structure (e.g., presence of configuration files)

**See Also:**
- [Implementing Frameworks Guide](IMPLEMENTING_FRAMEWORKS.md) - Detailed implementation instructions
- [Framework Documentation](framework-*.md) - Individual framework guides

## JRE Components

JRE components represent the Java Runtime Environment that will be used when running an application. JRE types include OpenJDK (default), Zulu, GraalVM, IBM JRE, Oracle JRE, and other vendor-specific distributions.

**Responsibilities:**
- Detect which JRE should be used (via environment variables or configuration)
- Download and install the JRE
- Install JRE components (Memory Calculator, JVMKill agent)
- Set up JAVA_HOME and PATH for runtime
- Resolve JRE-specific JVM options

**Implementation:**
JRE components implement the `JRE` interface defined in `src/java/jres/jre.go`:

```go
type JRE interface {
    Name() string
    Detect() (bool, error)
    Supply() error
    Finalize() error
    JavaHome() string
    Version() string
}
```

**Available JREs:**
- **OpenJDK**: Default JRE, always available
- **Zulu**: Azul Systems OpenJDK distribution
- **GraalVM**: High-performance JVM with native image support
- **IBM JRE**: IBM Java Runtime Environment
- **Oracle JRE**: Oracle Java SE
- **SapMachine**: SAP's OpenJDK distribution
- **Azul Platform Prime (Zing)**: Low-latency JVM

**Detection Order:**
Only a single JRE component can be used to run an application. JREs are detected in registry order:
1. Explicitly configured JRE (via `JBP_CONFIG_COMPONENTS`)
2. OpenJDK (default/fallback)

If more than one JRE can be used, the first match wins. If no JRE is detected, an error will be raised and application deployment will fail.

**JRE Components:**
Each JRE installation includes:
- **Memory Calculator**: Computes optimal JVM memory settings based on container limits
- **JVMKill Agent**: Forcibly terminates JVM on OutOfMemoryError
- **Profile.d Scripts**: Export JAVA_HOME and PATH at runtime

**Version Selection:**
Users can specify Java version via:
```bash
# Simple version
cf set-env myapp BP_JAVA_VERSION 17

# Version pattern
cf set-env myapp BP_JAVA_VERSION "21.*"

# Legacy config
cf set-env myapp JBP_CONFIG_OPEN_JDK_JRE '{jre: {version: 11.+}}'
```

**See Also:**
- [Implementing JREs Guide](IMPLEMENTING_JRES.md) - Detailed implementation instructions
- [JRE Documentation](jre-*.md) - Individual JRE guides

## Component Lifecycle

### Supply Phase

During the supply phase (`bin/supply`), the buildpack:

1. **Detects JRE**: Finds the appropriate JRE provider
2. **Installs JRE**: Downloads and extracts the Java runtime
3. **Detects Frameworks**: Identifies required frameworks
4. **Installs Frameworks**: Downloads and installs framework components
5. **Detects Container**: Finds the appropriate container type
6. **Prepares Container**: Downloads and configures the container

Components can write to:
- `$DEPS_DIR/<idx>/`: Dependency installation directory
- `$BUILD_DIR/`: Application directory (transformed in-place)
- `$CACHE_DIR/`: Persistent cache across builds

### Finalize Phase

During the finalize phase (`bin/finalize`), the buildpack:

1. **Finalizes JRE**: Configures JVM options, memory calculator
2. **Finalizes Frameworks**: Adds agent paths, system properties
3. **Finalizes Container**: Generates launch command

Components can:
- Read installed dependencies from `$DEPS_DIR/<idx>/`
- Write runtime scripts to `.profile.d/`
- Generate the final launch command

### Runtime

At runtime, Cloud Foundry:

1. Sources `.profile.d/*.sh` scripts (sets JAVA_HOME, JAVA_OPTS)
2. Executes the launch command generated by the container
3. Runs the application with configured JRE and frameworks

## Component Registration

Components are registered in `src/java/supply/supply.go` and `src/java/finalize/finalize.go`:

```go
// Register JREs
jreRegistry := jres.NewRegistry(jreCtx)
jreRegistry.Register(jres.NewOpenJDKJRE(jreCtx))
jreRegistry.Register(jres.NewZuluJRE(jreCtx))
// ... more JREs

// Register Frameworks
frameworks := []frameworks.Framework{
    frameworks.NewNewRelicAgent(frameworkCtx),
    frameworks.NewAppDynamicsAgent(frameworkCtx),
    // ... more frameworks
}

// Register Containers
containers := []containers.Container{
    containers.NewDistZip(containerCtx),
    containers.NewGroovy(containerCtx),
    containers.NewJavaMain(containerCtx),
    // ... more containers
}
```

## Configuration

The buildpack can be configured via:

### Environment Variables

**Buildpack-wide:**
- `BP_LOG_LEVEL`: Logging level (DEBUG, INFO, WARNING, ERROR)
- `BP_JAVA_VERSION`: Java version to install (e.g., "17", "21.*")

**Component-specific:**
- `JBP_CONFIG_COMPONENTS`: Override component selection
- `JBP_CONFIG_<COMPONENT>`: Component-specific configuration (JSON/YAML)

Example:
```bash
cf set-env myapp BP_JAVA_VERSION 17
cf set-env myapp JBP_CONFIG_NEW_RELIC_AGENT '{enabled: true}'
cf set-env myapp JBP_CONFIG_COMPONENTS '{jres: ["ZuluJRE"]}'
```

### Configuration Files

Component defaults are defined in `config/*.yml`:
- `config/components.yml`: Component detection order
- `config/open_jdk_jre.yml`: OpenJDK configuration
- `config/tomcat.yml`: Tomcat configuration
- `config/new_relic_agent.yml`: New Relic configuration

## Manifest

The buildpack manifest (`manifest.yml`) defines available dependencies:

```yaml
dependencies:
  - name: openjdk
    version: 17.0.13
    uri: https://github.com/.../openjdk-17.0.13.tar.gz
    sha256: abc123...
    cf_stacks: [cflinuxfs4]

  - name: tomcat
    version: 9.0.95
    uri: https://archive.apache.org/.../tomcat-9.0.95.tar.gz
    sha256: def456...
    cf_stacks: [cflinuxfs4]
```

Dependencies are:
- Downloaded during supply phase
- Cached for subsequent builds
- Verified with SHA256 checksums

## Extension Points

The buildpack can be extended by:

1. **Adding JREs**: Implement the `JRE` interface and register in supply/finalize
2. **Adding Frameworks**: Implement the `Framework` interface and register in supply/finalize
3. **Adding Containers**: Implement the `Container` interface and register in supply/finalize
4. **Forking**: Create a custom buildpack based on this codebase

See the implementation guides for detailed instructions:
- [Implementing JREs](IMPLEMENTING_JRES.md)
- [Implementing Frameworks](IMPLEMENTING_FRAMEWORKS.md)
- [Implementing Containers](IMPLEMENTING_CONTAINERS.md)

## Project Structure

```
java-buildpack/
├── bin/
│   ├── compile         # Main entry point (supply + finalize)
│   ├── supply          # Supply phase binary
│   └── finalize        # Finalize phase binary
├── config/
│   ├── components.yml  # Component registration
│   ├── *.yml          # Component configurations
├── docs/
│   ├── ARCHITECTURE.md           # Architecture overview
│   ├── DEVELOPING.md             # Development guide
│   ├── IMPLEMENTING_JRES.md      # JRE implementation
│   ├── IMPLEMENTING_FRAMEWORKS.md # Framework implementation
│   ├── IMPLEMENTING_CONTAINERS.md # Container implementation
│   └── TESTING.md                # Testing guide
├── src/java/
│   ├── containers/     # Container implementations
│   ├── frameworks/     # Framework implementations
│   ├── jres/           # JRE implementations
│   ├── supply/         # Supply phase logic
│   └── finalize/       # Finalize phase logic
└── manifest.yml        # Dependency manifest
```

## Technology Stack

- **Language**: Go 1.21+
- **Libraries**:
  - `github.com/cloudfoundry/libbuildpack`: Core buildpack utilities
  - `github.com/onsi/ginkgo/v2`: BDD testing framework
  - `github.com/onsi/gomega`: Matcher library
  - `github.com/cloudfoundry/switchblade`: Integration testing
- **Build Tools**:
  - `go build`: Compile binaries
  - `ginkgo`: Run tests
  - `gofmt`, `goimports`: Code formatting

## Further Reading

- [Architecture Guide](../ARCHITECTURE.md) - Detailed architecture and patterns
- [Development Guide](DEVELOPING.md) - Building and testing the buildpack
- [Testing Guide](TESTING.md) - Test framework and best practices
- [Contributing Guide](../CONTRIBUTING.md) - Contribution guidelines
