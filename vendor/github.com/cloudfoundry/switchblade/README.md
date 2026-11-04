# Switchblade

Switchblade is an integration testing framework for Cloud Foundry v2b
buildpacks. It enables test authors to write tests once, and then run them
either against a real Cloud Foundry, or their local Docker daemon.

In either case, the author should only need to change the values passed to
`switchblade.NewPlatform` to swap one platform for the other. No other changes
to the test suite should be required.

In addition to the goal of platform swapping, Switchblade enables better
testing of buildpack functionality including offline support and
service-binding integrations. Both of these features are supported in a manner
that best aligns with how a real buildpack user would use those features. That
is to say, the Cloud Foundry platform only uses Cloud Foundry, and the Docker
platform only uses Docker. There is no other "magic".

## Examples

### Running with Cloud Foundry

```go
package integration_test

import (
  "log"
  "testing"

  "github.com/cloudfoundry/switchblade"

  . "github.com/onsi/gomega"
  . "github.com/cloudfoundry/switchblade/matchers"
)

func TestCloudFoundry(t *testing.T) {
  var (
    Expect     = NewWithT(t).Expect
    Eventually = NewWithT(t).Eventually
  )

  // Create an instance of a Cloud Foundry platform. A GitHub token is required
  // to make API requests to GitHub fetching buildpack details.
  platform, err := switchblade.NewPlatform(switchblade.CloudFoundry, "<github-api-token>")
  Expect(err).NotTo(HaveOccurred())

  // Deploy an application called "my-app" onto Cloud Foundry with source code
  // located at /path/to/my/app/source. This is similar to the following `cf`
  // command:
  //   cf push my-app -p /path/to/my/app
  deployment, logs, err := platform.Deploy.Execute("my-app", "/path/to/my/app/source")
  Expect(err).NotTo(HaveOccurred())

  // Assert that the deployment logs contain a line that contains the substring
  // "Installing dependency..."
  Expect(logs).To(ContainLines(ContainSubstring("Installing dependency...")))

  // Assert that the deployment results in an application instance that serves
  // "Hello, world!" over HTTP.
  Eventually(deployment).Should(Serve(ContainSubstring("Hello, world!")))

  // Delete the application from the platform.
  Expect(platform.Delete.Execute("my-app")).To(Succeed())
}
```

### Running with Docker

```go
package integration_test

import (
  "log"
  "testing"

  "github.com/cloudfoundry/switchblade"

  . "github.com/onsi/gomega"
  . "github.com/cloudfoundry/switchblade/matchers"
)

func TestDocker(t *testing.T) {
  var (
    Expect     = NewWithT(t).Expect
    Eventually = NewWithT(t).Eventually
  )

  // Create an instance of a Docker platform. A GitHub token is required to
  // make API requests to GitHub fetching buildpack details.
  platform, err := switchblade.NewPlatform(switchblade.Docker, "<github-api-token>")
  Expect(err).NotTo(HaveOccurred())

  // Deploy an application called "my-app" onto Docker with source code
  // located at /path/to/my/app/source. This is similar to the following `cf`
  // command, but running locally on your Docker daemon:
  //   cf push my-app -p /path/to/my/app
  deployment, logs, err := platform.Deploy.Execute("my-app", "/path/to/my/app/source")
  Expect(err).NotTo(HaveOccurred())

  // Assert that the deployment logs contain a line that contains the substring
  // "Installing dependency..."
  Expect(logs).To(ContainLines(ContainSubstring("Installing dependency...")))

  // Assert that the deployment results in an application instance that serves
  // "Hello, world!" over HTTP.
  Eventually(deployment).Should(Serve(ContainSubstring("Hello, world!")))

  // Delete the application from the platform.
  Expect(platform.Delete.Execute("my-app")).To(Succeed())
}
```

On Docker, the buildpacks are bundled into a tarball under
`~/.switchblade/buildpacks` that is built once per set of buildpacks and
reused by every deployment. It is rebuilt when a local buildpack zip or
directory changes. The three most recently used tarballs are kept.

Two settings speed up staging on Docker:

- On by default: droplet and build cache compress with the fastest gzip level. The droplet
  contents are unchanged, only the archive is slightly larger. The lifecycle
  runs `tar -czf`, which takes no compression level, and the `GZIP`
  environment variable is deprecated. So Switchblade copies a small wrapper,
  `exec /usr/bin/gzip -1 "$@"`, to `/usr/local/bin/gzip` in each staging
  container (not on the host), ahead of `/usr/bin` on the stack `PATH`. A
  buildpack that runs `gzip` during staging also gets level 1, unless it
  passes its own level.
- Opt-in: set `SWITCHBLADE_SKIP_BUILD_CACHE=true` to neither restore nor save
  the build cache between deployments. Only opt in when no test relies on the
  build cache of an earlier deployment with the same name, for example a test
  that pushes the same app twice and expects the second staging to reuse
  cached dependencies.

### Specifying buildpacks: `WithBuildpacks`

```go
// Deploy an application called "my-app" with source code located at
// /path/to/my/app/source. Only use the "ruby_buildpack" and the "go_buildpack".
// This is similar to the following `cf` command:
//   cf push my-app -p /path/to/my/app -b ruby_buildpack -b go_buildpack
deployment, logs, err := platform.Deploy.
  WithBuildpacks("ruby_buildpack", "go_buildpack").
  Execute("my-app", "/path/to/my/app/source")
```

### Specifying environment variables: `WithEnv`

```go
// Deploy an application called "my-app" with source code located at
// /path/to/my/app/source. This is similar to running the following `cf`
// command:
//   cf set-env my-app SOME_KEY some-value
deployment, logs, err := platform.Deploy.
  WithEnv(map[string]string{
    "SOME_KEY": "some-value",
  }).
  Execute("my-app", "/path/to/my/app/source")
```

### Disabling internet access: `WithoutInternetAccess`

```go
// Deploy an application called "my-app" with source code located at
// /path/to/my/app/source. This will disable internet access for the staging
// process.
deployment, logs, err := platform.Deploy.
  WithoutInternetAccess().
  Execute("my-app", "/path/to/my/app/source")
```

### Specifying service bindings: `WithServices`

```go
// Deploy an application called "my-app" with source code located at
// /path/to/my/app/source. This is similar to running the following `cf`
// commands:
//   cf create-user-provided-service my-app-my-service -p '{"password": "its-a-secret!"}'
//   cf bind-service my-app my-app-my-service
deployment, logs, err := platform.Deploy.
  WithService(map[string]switchblade.Service{
    "my-service": {
      "password": "its-a-secret!",
    },
  }).
  Execute("my-app", "/path/to/my/app/source")
```

### Specifying a start command: `WithStartCommand`

```go
// Deploy an application called "my-app" with source code located at
// /path/to/my/app/source. This is similar to running the following `cf`
// commands:
//   cf push my-app -c "start my-app"
deployment, logs, err := platform.Deploy.
  WithStartCommand("start my-app").
  Execute("my-app", "/path/to/my/app/source")
```

### Retrieving runtime logs: `RuntimeLogs`

The `deployment.RuntimeLogs()` method retrieves logs from the running application
after deployment succeeds. This is useful for testing runtime behavior such as
application startup, service connections, and module loading.

```go
// Deploy an application
deployment, stagingLogs, err := platform.Deploy.Execute("my-app", "/path/to/my/app/source")
Expect(err).NotTo(HaveOccurred())

// stagingLogs contains build-time output (buildpack detection, compilation, etc.)
Expect(stagingLogs).To(ContainLines(ContainSubstring("Installing dependencies...")))

// Retrieve runtime logs (application startup, service connections, etc.)
runtimeLogs, err := deployment.RuntimeLogs()
Expect(err).NotTo(HaveOccurred())
Expect(runtimeLogs).To(ContainSubstring("Application started"))
Expect(runtimeLogs).To(ContainSubstring("Connected to Redis"))
```

**Note:** The logs returned from `platform.Deploy.Execute()` are **staging logs**
(build-time), while `deployment.RuntimeLogs()` returns **runtime logs** (post-deployment).
Use staging logs to test buildpack behavior, and runtime logs to test application behavior.

## Other utilities

### Random name generation: `RandomName`

The `switchblade.RandomName` helper can generate random names. This is useful
for keeping your applications reasonably namespaced in the shared platform. The
names generated will include the prefix `switchblade-` following by a
[ULID](https://github.com/ulid/spec).

```go
name, err := switchblade.RandomName()
if err != nil {
  log.Fatal(err)
}

fmt.Println(name) // Outputs: switchblade-<some-ulid>
```

## Releasing

Releases are cut from `main` by the
[Create Draft Release](.github/workflows/create-draft-release.yml) workflow.
On every push to `main` it deletes the previous draft, bumps the tag, and
creates a new draft release.

The draft body is taken from the `## [Unreleased]` section of
[`CHANGELOG.md`](CHANGELOG.md). If that section is empty, the workflow falls
back to GitHub's auto-generated release notes (`What's Changed`).

Because the draft is recreated on every push, do not edit the draft release
body by hand — it will be overwritten. Instead:

1. Add entries under `## [Unreleased]` in `CHANGELOG.md` as changes land.
   Each push to `main` refreshes the draft with that section.
2. Review the draft, then publish it.
3. Afterwards, in a follow-up change, rename `## [Unreleased]` to the
   published version (for example `## [v0.10.0] - 2026-11-02`) and leave a
   fresh, empty `## [Unreleased]` section at the top.

Do the rename only *after* publishing: a push to `main` deletes the existing
draft, so promoting the section beforehand would discard the notes for the
release being cut. Until new entries are added, the next draft falls back to
GitHub-generated notes.
