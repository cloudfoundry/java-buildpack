# Developing the Java Buildpack

This guide covers setting up your development environment, building the buildpack, running tests, and common development workflows for the Go-based Cloud Foundry Java Buildpack.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Building the Buildpack](#building-the-buildpack)
- [Running Tests](#running-tests)
- [Development Workflow](#development-workflow)
- [Local Testing with Cloud Foundry](#local-testing-with-cloud-foundry)
- [Packaging the Buildpack](#packaging-the-buildpack)
- [Debugging](#debugging)
- [Common Tasks](#common-tasks)

## Prerequisites

Before you begin, ensure you have the following installed:

### Required

- **Go 1.21 or later** - [Download](https://golang.org/dl/)
  ```bash
  go version  # Should show 1.21 or higher
  ```

- **Git** - For version control
  ```bash
  git --version
  ```

- **jq** - For JSON processing in build scripts
  ```bash
  jq --version
  ```

### Optional (for integration testing)

- **Docker** - For running integration tests locally
  ```bash
  docker --version
  ```

- **Cloud Foundry CLI (cf)** - For testing against a real CF deployment
  ```bash
  cf version
  ```

- **Ginkgo** - Test framework (will be installed automatically by scripts)
  ```bash
  go install github.com/onsi/ginkgo/v2/ginkgo@latest
  ```

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/cloudfoundry/java-buildpack.git
cd java-buildpack
```

### 2. Verify Dependencies

The buildpack uses Go modules with vendored dependencies. Verify that all dependencies are present:

```bash
# Check vendored dependencies
ls vendor/

# Download dependencies if needed (usually not required)
go mod download
```

### 3. Install Build Tools

The build scripts will automatically install required tools (like `ginkgo`) when needed:

```bash
./scripts/install_tools.sh
```

This installs:
- Ginkgo v2 test framework
- Buildpack packager (for creating distributable packages)

### 4. Build the Buildpack

Build the buildpack binaries:

```bash
./scripts/build.sh
```

This creates executables in the `bin/` directory:
- `bin/supply` - Staging phase binary (downloads and installs dependencies)
- `bin/finalize` - Finalization phase binary (configures runtime)

## Project Structure

```
java-buildpack/
├── bin/                      # Compiled binaries (generated)
│   ├── supply               # Supply phase executable
│   └── finalize             # Finalize phase executable
├── src/java/                # Go source code
│   ├── containers/          # Container implementations (8 types)
│   ├── frameworks/          # Framework implementations (38 types)
│   ├── jres/                # JRE implementations (7 providers)
│   ├── supply/cli/          # Supply phase entrypoint
│   ├── finalize/cli/        # Finalize phase entrypoint
│   └── integration/         # Integration tests
├── config/                  # YAML configuration files
│   ├── components.yml       # Component registry
│   ├── open_jdk_jre.yml    # Example: OpenJDK configuration
│   └── ...                  # Component-specific configs
├── resources/               # Static resources (templates, configs)
├── scripts/                 # Build and test scripts
│   ├── build.sh            # Build binaries
│   ├── unit.sh             # Run unit tests
│   ├── integration.sh      # Run integration tests
│   └── package.sh          # Package buildpack for deployment
├── vendor/                  # Vendored Go dependencies
├── go.mod                   # Go module definition
├── go.sum                   # Dependency checksums
├── manifest.yml             # Buildpack manifest
└── VERSION                  # Version number

Key Go Packages:
- containers/   - Application container implementations (Tomcat, Spring Boot, etc.)
- frameworks/   - Framework integrations (APM agents, security providers, etc.)
- jres/         - JRE providers (OpenJDK, Zulu, GraalVM, etc.)
- supply/       - Staging phase logic
- finalize/     - Runtime configuration logic
```

## Building the Buildpack

### Standard Build

Build for the default platform (Linux):

```bash
./scripts/build.sh
```

**Output:**
```
-----> Building supply for linux
-----> Building finalize for linux
-----> Build complete
```

### Cross-Platform Build

The buildpack supports building for multiple platforms defined in `config.json`:

```json
{
  "oses": ["linux", "windows"]
}
```

The build script automatically builds for all configured platforms:

```bash
./scripts/build.sh
# Creates: bin/supply, bin/finalize, bin/supply.exe, bin/finalize.exe
```

### Build Options

The build uses these Go build flags:
- `-mod vendor` - Use vendored dependencies
- `-ldflags="-s -w"` - Strip debug symbols (smaller binary size)
- `CGO_ENABLED=0` - Static linking (no external dependencies)

### Manual Build

To build manually for development:

```bash
# Build supply
go build -mod vendor -o bin/supply src/java/supply/cli/main.go

# Build finalize
go build -mod vendor -o bin/finalize src/java/finalize/cli/main.go
```

## Running Tests

The buildpack has comprehensive test coverage with unit tests and integration tests.

### Unit Tests

Run all unit tests:

```bash
./scripts/unit.sh
```

**What it does:**
- Runs all Ginkgo tests in `src/java/` (excluding integration tests)
- Tests containers, frameworks, JREs, and utility packages
- Fast execution (~30 seconds)

**Sample output:**
```
-----> Running unit tests
Running Suite: Containers
...
Running Suite: Frameworks
...
Ran 427 of 427 Specs in 28.543 seconds
SUCCESS! -- 427 Passed | 0 Failed | 0 Pending | 0 Skipped
-----> Unit tests complete
```

### Run Specific Tests

Using Ginkgo directly:

```bash
# Test a specific package
cd src/java
ginkgo frameworks/

# Test a specific file
ginkgo frameworks/new_relic_test.go

# Run tests matching a pattern
ginkgo --focus="NewRelic" frameworks/

# Run tests with verbose output
ginkgo -v frameworks/
```

### Integration Tests

Integration tests require a packaged buildpack and either Docker or a Cloud Foundry deployment.

**Prerequisites:**
1. Package the buildpack (see [Packaging](#packaging-the-buildpack))
2. Set `BUILDPACK_FILE` environment variable

**Run with Docker:**

```bash
# Package the buildpack first
./scripts/package.sh --version dev

# Run integration tests
export BUILDPACK_FILE="${PWD}/build/buildpack.zip"
./scripts/integration.sh --platform docker
```

**Run with Cloud Foundry:**

```bash
export BUILDPACK_FILE="${PWD}/build/buildpack.zip"
./scripts/integration.sh --platform cf --stack cflinuxfs4
```

**Integration test options:**

```bash
# Run in parallel (faster, uses GOMAXPROCS=2)
./scripts/integration.sh --platform docker --parallel true

# Run cached/offline tests
./scripts/integration.sh --platform docker --cached true

# Keep failed containers for debugging
./scripts/integration.sh --platform docker --keep-failed-containers

# Specify GitHub token for API rate limiting
./scripts/integration.sh --platform docker --github-token YOUR_TOKEN
```

**Integration test suites:**
- `dist_zip_test.go` - DistZip container tests
- `frameworks_test.go` - Framework detection and installation
- `groovy_test.go` - Groovy application tests
- `java_main_test.go` - Java Main container tests
- `play_test.go` - Play Framework tests
- `ratpack_test.go` - Ratpack tests
- `spring_boot_test.go` - Spring Boot tests
- `spring_boot_cli_test.go` - Spring Boot CLI tests
- `tomcat_test.go` - Tomcat container tests
- `offline_test.go` - Offline buildpack tests

### Test Coverage

Check test coverage:

```bash
cd src/java
go test -cover ./containers/...
go test -cover ./frameworks/...
go test -cover ./jres/...
```

### Continuous Testing

Watch for changes and re-run tests:

```bash
cd src/java
ginkgo watch -r frameworks/
```

## Development Workflow

### Typical Development Cycle

1. **Make changes** to Go source files in `src/java/`

2. **Run unit tests** to verify changes:
   ```bash
   ./scripts/unit.sh
   ```

3. **Build the buildpack** to ensure it compiles:
   ```bash
   ./scripts/build.sh
   ```

4. **Run integration tests** (optional, for significant changes):
   ```bash
   ./scripts/package.sh --version dev
   export BUILDPACK_FILE="${PWD}/build/buildpack.zip"
   ./scripts/integration.sh --platform docker
   ```

5. **Test with a real application** (see [Local Testing](#local-testing-with-cloud-foundry))

6. **Commit changes** following the [Contributing Guide](../CONTRIBUTING.md)

### Making Changes

#### Adding a New Framework

See [Implementing Frameworks](IMPLEMENTING_FRAMEWORKS.md) for detailed instructions.

**Quick overview:**
1. Create `src/java/frameworks/my_framework.go`
2. Implement the `Component` interface
3. Create `src/java/frameworks/my_framework_test.go`
4. Add configuration to `config/my_framework.yml`
5. Register in `config/components.yml`
6. Add documentation to `docs/framework-my_framework.md`

#### Modifying Existing Components

1. **Find the component:**
   - Containers: `src/java/containers/`
   - Frameworks: `src/java/frameworks/`
   - JREs: `src/java/jres/`

2. **Edit the Go file** and its corresponding test file

3. **Update configuration** if needed (in `config/` directory)

4. **Run tests:**
   ```bash
   # Test the specific component
   cd src/java
   ginkgo frameworks/my_framework_test.go
   
   # Run all unit tests
   cd ../..
   ./scripts/unit.sh
   ```

#### Updating Dependencies

The buildpack uses Go modules with vendored dependencies:

```bash
# Add a new dependency
go get github.com/example/package@v1.2.3

# Update dependencies
go get -u ./...

# Vendor dependencies
go mod vendor

# Verify
go mod verify
```

## Local Testing with Cloud Foundry

### Using Docker (Recommended for Quick Testing)

The fastest way to test changes locally:

```bash
# 1. Build and package
./scripts/build.sh
./scripts/package.sh --version dev

# 2. Run integration tests with Docker
export BUILDPACK_FILE="${PWD}/build/buildpack.zip"
./scripts/integration.sh --platform docker

# 3. Test specific application types
./scripts/integration.sh --platform docker --focus="Spring Boot"
```

### Using Cloud Foundry

For testing against a real Cloud Foundry deployment:

```bash
# 1. Target your CF environment
cf api https://api.your-cf.com
cf login

# 2. Package the buildpack
./scripts/package.sh --version dev

# 3. Create/update custom buildpack
cf create-buildpack java-buildpack-dev build/buildpack.zip 99 --enable
# OR update existing:
cf update-buildpack java-buildpack-dev -p build/buildpack.zip

# 4. Deploy a test application
cd /path/to/test/app
cf push my-test-app -b java-buildpack-dev

# 5. Check logs
cf logs my-test-app --recent
```

### Test Applications

The [Java Test Applications](https://github.com/cloudfoundry/java-test-applications) repository contains sample apps for testing:

```bash
git clone https://github.com/cloudfoundry/java-test-applications.git
cd java-test-applications

# Build a test app (requires Maven/Gradle)
cd web-servlet
./mvnw package

# Deploy with your custom buildpack
cf push servlet-test -b java-buildpack-dev -p target/web-servlet-1.0.0.BUILD-SNAPSHOT.war
```

## Packaging the Buildpack

### Online Package

Create a minimal package that downloads dependencies at runtime:

```bash
./scripts/package.sh --version 1.0.0
```

**Output:** `build/buildpack.zip` (~250KB)

### Offline Package

Create a package with all dependencies cached (no internet required at runtime):

```bash
./scripts/package.sh --version 1.0.0 --cached
```

**Output:** `build/buildpack.zip` (~500MB, varies based on cached dependencies)

### Package Options

```bash
# Specify version
./scripts/package.sh --version 4.50.0

# Specify output location
./scripts/package.sh --version dev --output /tmp/my-buildpack.zip

# Specify stack
./scripts/package.sh --version dev --stack cflinuxfs4

# Offline with custom stack
./scripts/package.sh --version 1.0.0 --cached --stack cflinuxfs4
```

### Automated Packaging (CI/CD)

The `ci/` directory contains scripts for automated packaging:

```bash
# Package and test in CI environment
./ci/package-test.sh
```

## Debugging

### Enable Debug Logging

Set the `JBP_LOG_LEVEL` environment variable:

```bash
cf set-env my-app JBP_LOG_LEVEL DEBUG
cf restage my-app
```

**Log levels:** `DEBUG`, `INFO`, `WARN`, `ERROR`

### Debug During Staging

View buildpack output during staging:

```bash
cf push my-app -b java-buildpack-dev
# Watch output in real-time
```

### Debug Running Application

Enable remote debugging framework:

```bash
cf set-env my-app JBP_CONFIG_DEBUG '{enabled: true}'
cf restage my-app
cf ssh -N -T -L 8000:localhost:8000 my-app
```

Then connect your IDE debugger to `localhost:8000`.

See [Framework Debug](framework-debug.md) for details.

### Inspect Buildpack Artifacts

Extract buildpack contents from a running container:

```bash
# SSH into the container
cf ssh my-app

# Check installed components
ls -la /home/vcap/app/.java-buildpack/

# View profile.d scripts (executed at startup)
cat /home/vcap/app/.profile.d/*.sh
```

### Debug Integration Tests

Keep failed test containers for inspection:

```bash
export BUILDPACK_FILE="${PWD}/build/buildpack.zip"
./scripts/integration.sh --platform docker --keep-failed-containers

# Find the container
docker ps -a | grep failed

# Inspect the container
docker exec -it <container-id> /bin/bash
```

### Debug Unit Tests

Run tests with verbose output:

```bash
cd src/java
ginkgo -v frameworks/new_relic_test.go

# Add print statements in test or source code
fmt.Printf("DEBUG: value = %+v\n", someVar)
```

## Common Tasks

### Update Framework Version

1. Edit `config/my_framework.yml`:
   ```yaml
   version: 1.2.3
   repository_root: "{default.repository.root}/my-framework"
   ```

2. Test the change:
   ```bash
   ./scripts/unit.sh
   ./scripts/build.sh
   ```

### Add New Configuration Option

1. Update the config struct in `src/java/frameworks/my_framework.go`:
   ```go
   type Config struct {
       Enabled    bool   `yaml:"enabled"`
       Version    string `yaml:"version"`
       NewOption  string `yaml:"new_option"`  // Add this
   }
   ```

2. Update default configuration in `config/my_framework.yml`:
   ```yaml
   enabled: true
   version: 1.+
   new_option: "default_value"
   ```

3. Update tests in `src/java/frameworks/my_framework_test.go`

### Run a Single Integration Test

```bash
export BUILDPACK_FILE="${PWD}/build/buildpack.zip"
cd src/integration
go test -v -run TestSpringBoot
```

### Check for Common Issues

```bash
# Verify Go formatting
gofmt -d src/java/

# Format all code
gofmt -w src/java/

# Run go vet
go vet ./src/java/...

# Check for common mistakes
golint ./src/java/...  # Install with: go install golang.org/x/lint/golint@latest
```

### Clean Build Artifacts

```bash
# Remove built binaries
rm -rf bin/

# Remove packaged buildpacks
rm -rf build/

# Clean and rebuild
./scripts/build.sh
```

### Update Vendored Dependencies

```bash
# Update a specific dependency
go get github.com/cloudfoundry/libbuildpack@latest

# Update all dependencies
go get -u ./...

# Re-vendor
go mod tidy
go mod vendor

# Test everything still works
./scripts/unit.sh
```

## Next Steps

- **[Implementing Frameworks](IMPLEMENTING_FRAMEWORKS.md)** - Learn how to add new framework support
- **[Implementing Containers](IMPLEMENTING_CONTAINERS.md)** - Learn how to add new container types
- **[Testing Guide](TESTING.md)** - Comprehensive testing patterns and best practices
- **[Contributing Guidelines](../CONTRIBUTING.md)** - Contribution standards and code style
- **[Architecture Overview](../ARCHITECTURE.md)** - Deep dive into buildpack architecture

## Getting Help

- **Documentation:** `docs/` directory contains comprehensive guides
- **Issues:** [GitHub Issues](https://github.com/cloudfoundry/java-buildpack/issues)
- **Slack:** [Cloud Foundry Slack](https://slack.cloudfoundry.org) - #buildpacks channel
- **Mailing List:** [cf-dev mailing list](https://lists.cloudfoundry.org/g/cf-dev)

## Troubleshooting

### "command not found: ginkgo"

Install Ginkgo:
```bash
go install github.com/onsi/ginkgo/v2/ginkgo@latest
export PATH="${PATH}:${HOME}/go/bin"
```

### "BUILDPACK_FILE not set" during integration tests

Set the environment variable:
```bash
export BUILDPACK_FILE="${PWD}/build/buildpack.zip"
```

### "cannot find package" errors

Ensure dependencies are vendored:
```bash
go mod vendor
go mod verify
```

### Tests failing after changes

1. Rebuild binaries: `./scripts/build.sh`
2. Check Go formatting: `gofmt -d src/java/`
3. Run tests with verbose output: `cd src/java && ginkgo -v`
4. Check for missing configuration in `config/` files

### Integration tests hanging

Increase Docker resources (memory/CPU) or run tests serially:
```bash
./scripts/integration.sh --platform docker --parallel false
```
