# Integration Tests

This directory contains integration tests for the Java buildpack using the [Switchblade](https://github.com/cloudfoundry/switchblade) framework.

## Overview

Switchblade is a Go-based integration testing framework that supports both Cloud Foundry and Docker platforms. This allows us to write tests once and run them on either platform.

## Prerequisites

- Go 1.25 or later
- Cloud Foundry CLI (if testing on CF)
- Docker (if testing on Docker)
- A packaged buildpack zip file
- **GitHub Personal Access Token** (required for Docker platform tests)
  - Create token at: https://github.com/settings/tokens
  - Requires `public_repo` or `repo` scope
  - Used to query buildpack metadata from GitHub API

## Running Tests

### Package the Buildpack

First, create a buildpack zip file:

```bash
bundle exec rake package
```

This will create a file like `java-buildpack-v4.x.x.zip` in the project root.

### Run Integration Tests

Use the provided script to run the tests:

```bash
# Test on Cloud Foundry (default)
BUILDPACK_FILE=/path/to/java-buildpack-v4.x.x.zip ./scripts/integration.sh

# Test on Docker (requires GitHub token)
BUILDPACK_FILE=/path/to/java-buildpack-v4.x.x.zip \
GITHUB_TOKEN=your_github_token_here \
./scripts/integration.sh --platform docker

# Run cached/offline tests
BUILDPACK_FILE=/path/to/java-buildpack-v4.x.x.zip ./scripts/integration.sh --cached

# Specify a different stack
BUILDPACK_FILE=/path/to/java-buildpack-v4.x.x.zip ./scripts/integration.sh --stack cflinuxfs4
```

### Run Tests Directly with Go

You can also run the tests directly using Go:

```bash
cd src/integration

# Run all tests
BUILDPACK_FILE=/path/to/buildpack.zip go test -v -timeout 30m

# Run specific test suite
BUILDPACK_FILE=/path/to/buildpack.zip go test -v -run TestIntegration/Tomcat

# Run on Docker
BUILDPACK_FILE=/path/to/buildpack.zip go test -v -platform=docker

# Run offline tests
BUILDPACK_FILE=/path/to/buildpack.zip go test -v -cached
```

## Test Organization

### Test Files

- `init_test.go` - Test suite initialization and configuration
- `tomcat_test.go` - Tomcat container tests
- `spring_boot_test.go` - Spring Boot application tests
- `java_main_test.go` - Java Main class application tests
- `offline_test.go` - Offline/cached buildpack tests

### Test Fixtures

Tests use fixtures from the `spec/fixtures` directory. The main fixture for integration tests is:
- `integration_valid` - A simple Java application with a Main-Class

## Configuration

### Environment Variables

- `BUILDPACK_FILE` (required) - Path to the packaged buildpack zip file
- `PLATFORM` - Platform to test against: `cf` (default) or `docker`
- `STACK` - Stack to use for tests (default: `cflinuxfs4`)
- `CACHED` - Run offline/cached tests (default: `false`)
- `GITHUB_TOKEN` - GitHub API token to avoid rate limiting

### Command-Line Flags

- `-platform` - Platform type (`cf` or `docker`)
- `-stack` - Stack name (e.g., `cflinuxfs4`)
- `-cached` - Enable offline tests
- `-github-token` - GitHub API token
- `-serial` - Run tests serially instead of in parallel

## Test Coverage

The integration tests cover:

1. **Container Types**
   - Tomcat container with WAR files
   - Spring Boot executable JARs
   - Java Main applications

2. **JRE Selection**
   - Java 8, 11, 17 runtime selection
   - Multiple JRE vendors (OpenJDK, Zulu, etc.)

3. **Configuration**
   - Memory calculator settings
   - Custom JAVA_OPTS
   - Framework-specific configuration

4. **Offline Mode**
   - Cached buildpack deployment
   - No internet access scenarios

## Writing New Tests

To add a new test:

1. Create a new test file in `src/integration/` (e.g., `myfeature_test.go`)
2. Define a test function that returns `func(*testing.T, spec.G, spec.S)`:
   ```go
   func testMyFeature(platform switchblade.Platform, fixtures string) func(*testing.T, spec.G, spec.S) {
       return func(t *testing.T, context spec.G, it spec.S) {
           // Your tests here
       }
   }
   ```
3. Register the test in `init_test.go`:
   ```go
   suite("MyFeature", testMyFeature(platform, fixtures))
   ```

## CI/CD Integration

To integrate with CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run Integration Tests
  env:
    BUILDPACK_FILE: ${{ github.workspace }}/java-buildpack.zip
    CF_API: ${{ secrets.CF_API }}
    CF_USERNAME: ${{ secrets.CF_USERNAME }}
    CF_PASSWORD: ${{ secrets.CF_PASSWORD }}
  run: |
    ./scripts/integration.sh --platform cf
```

## Comparison to Old Tests

The previous integration tests were:
- Located in a separate repository (`java-buildpack-system-test`)
- Written in Java with JUnit
- Only supported Cloud Foundry
- Required extensive configuration

The new Switchblade-based tests:
- Are co-located with the buildpack code
- Written in Go with Gomega matchers
- Support both Cloud Foundry and Docker
- Have simpler configuration and setup

## Troubleshooting

### Tests fail to compile
```bash
go mod tidy
go mod download
```

### Buildpack not found
Ensure the `BUILDPACK_FILE` environment variable points to a valid zip file:
```bash
ls -lh $BUILDPACK_FILE
```

### CF login issues
Ensure you're logged into Cloud Foundry:
```bash
cf login -a <api-endpoint>
```

### Docker issues
Ensure Docker is running and you have permission to use it:
```bash
docker ps
```
- The following error appears during staging while running an integration test:
```
Output:
            {"status":"Pulling from cloudfoundry/cflinuxfs4","id":"latest"}
            {"status":"Digest: sha256:77bf7297d2fbb4b787b73df2a4d0a911e5f0695321a6f0219a44c19be5d6bebe"}
            {"status":"Status: Image is up to date for cloudfoundry/cflinuxfs4:latest"}
            -----> Java Buildpack version dev
            -----> Supplying Java
                   Detected container: Tomcat
                   No JRE explicitly configured, using default: OpenJDK
                   Selected JRE: OpenJDK
            -----> Installing OpenJDK JRE
                   Installing OpenJDK 8.0.452
            -----> Installing openjdk 8.0.452
                   Download [https://java-buildpack.cloudfoundry.org/openjdk/jammy/x86_64/bellsoft-jre8u452%2B11-linux-amd64.tar.gz]
                   error: Get "https://java-buildpack.cloudfoundry.org/openjdk/jammy/x86_64/bellsoft-jre8u452%2B11-linux-amd64.tar.gz": dial tcp 104.18.17.211:443: connect: no route to host, retrying in 712.622241ms...
```
Check whether the URL, for which the issue appears, is accessible from the host machine. If the URL appears reachable and can be accessed successfully, check again from within the corresponding Switchblade container where the test is run. This can be achieved with `docker exec -it <container_id> /bin/bash` while the container is still up in order to access the container interactively and, for example, issue a `curl` to the URL from within it. If the `connect: no route to host` can be reproduced from within the corresponding Switchblade container, you can try the following in order to mitigate it:
  1. Execute `docker network prune` - this will remove any unused networks including `switchblade-internal` bridge networks set while running the integration tests.
  2. Execute `sudo systemctl restart docker` - this restarts Docker and resets its networking stack, which can resolve stale or broken network routes in the Docker daemon.

- Integration test is executed successfully but the following issue appears on test container removal:
```
tomcat_test.go:34: 
        Expected success, but got an error:
            <*fmt.wrapError | 0xc00034f140>: 
            failed to run teardown phase: failed to remove container: Error response from daemon: cannot remove container "switchblade-pqsal7svg": could not kill container: permission denied
            {
                msg: "failed to run teardown phase: failed to remove container: Error response from daemon: cannot remove container \"switchblade-pqsal7svg\": could not kill container: permission denied",
                err: <*fmt.wrapError | 0xc00034f0c0>{
                    msg: "failed to remove container: Error response from daemon: cannot remove container \"switchblade-pqsal7svg\": could not kill container: permission denied",
                    err: <errdefs.errSystem>{
                        error: <*errors.withStack | 0xc000405b60>{
                            error: <*errors.withMessage | 0xc00034f000>{
                                cause: <*errors.fundamental | 0xc000405b30>{
                                    msg: "cannot remove container \"switchblade-pqsal7svg\": could not kill container: permission denied",
                                    stack: [0x795cc0, 0x79517c, 0x790307, 0x7902a3, 0x7a2263, 0x7a807a, 0x7f6c2b, 0x7ad476, 0x7ad39f, 0x7acb35, 0x7abdb5, 0x52e46a, 0x485c21],
                                },
                                msg: "Error response from daemon",
                            },
                            stack: [0x795de5, 0x79517c, 0x790307, 0x7902a3, 0x7a2263, 0x7a807a, 0x7f6c2b, 0x7ad476, 0x7ad39f, 0x7acb35, 0x7abdb5, 0x52e46a, 0x485c21],
                        },
                    },
                },
            }
```

To mitigate the above issue try executing `sudo systemctl restart docker.socket docker.service`. This command restarts both the Docker systemd socket unit (which accepts client connections) and the main Docker daemon service. Doing so refreshes the daemon’s runtime state and can clear stale processes, file handles, or permission-related inconsistencies that prevent containers from being stopped or removed, resolving the `permission denied` error seen during teardown.

### GitHub authentication errors with Docker platform
If you see errors like "Bad credentials" or "401 Unauthorized" when running Docker platform tests:

```
failed to build buildpacks: failed to list buildpacks: received unexpected response status: HTTP/2.0 401 Unauthorized
```

This means you need to provide a GitHub Personal Access Token:

1. Create a token at https://github.com/settings/tokens
2. Grant it `public_repo` or `repo` scope
3. Export it as an environment variable:
   ```bash
   export GITHUB_TOKEN=your_token_here
   BUILDPACK_FILE=/path/to/buildpack.zip ./scripts/integration.sh --platform docker
   ```

Alternatively, pass it via the command line:
```bash
BUILDPACK_FILE=/path/to/buildpack.zip ./scripts/integration.sh --platform docker --github-token your_token_here
```

## References

- [Switchblade Documentation](https://github.com/cloudfoundry/switchblade)
- [Go Testing Documentation](https://golang.org/pkg/testing/)
- [Gomega Matchers](https://onsi.github.io/gomega/)
- [Cloud Foundry Buildpack Documentation](https://docs.cloudfoundry.org/buildpacks/)
