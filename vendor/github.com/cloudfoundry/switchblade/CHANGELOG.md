# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Docker platform: buildpacks are now cached as a shared tarball and
  reused across all apps that need the same buildpack set, instead of
  being rebuilt per app. The cache key is a SHA-256 over the buildpack
  names and URIs; for local buildpacks it also covers file size and
  modification time (not file contents). Significantly reduces build
  time and disk use on repeated/parallel deployments. Internal to the
  Docker platform; no public API changes. (#136)
- Docker platform: staging now uses a faster `gzip -1` for the tarballs
  created during staging. This is always on and has no opt-out. (#137)
- Docker platform: new opt-in environment variable
  `SWITCHBLADE_SKIP_BUILD_CACHE=true` skips the build cache during
  staging (no restore, no copy-out, no recompression). It is off by
  default because buildpack tests that deploy the same app twice and
  expect the second staging to reuse the cache would fail. (#137)
- Docker platform: app names are validated against path traversal and
  reserved names (`shared`, `buildpacks-shared`) before being used to
  construct filesystem paths, preventing a maliciously or accidentally
  named app from corrupting the shared build cache or escaping its
  staging directory. (#136)

### Fixed
- Docker platform: the shared buildpack cache key now uses the full
  256-bit SHA-256 digest instead of a 64-bit truncation, removing the
  risk of two distinct buildpack sets colliding on the same cache key.
  (#136)
- Docker platform: symlinked local/directory buildpacks are now copied
  by their resolved real path, so the packaged tarball contains the full
  directory contents instead of a broken symlink stub. (#136)
- Docker platform: stale leftover build artifacts from killed or crashed
  processes are now cleaned up on every build, including cache hits, not
  only on cache misses. (#136)

### Changed
- Dependencies bumped: `github.com/onsi/gomega` v1.36.2 → v1.42.0,
  `github.com/opencontainers/image-spec` v1.1.0 → v1.1.1,
  `github.com/paketo-buildpacks/packit/v2` v2.16.0 → v2.25.3,
  `github.com/docker/go-connections` v0.4.0 → v0.8.2; `go` directive
  1.23.0 → 1.24.6. Versions were capped below the next major bump
  (`packit/v2` v2.25.4+, `gomega` v1.43.0+) because those require
  Go ≥ 1.25, which this project's pinned `golangci-lint` cannot lint.
  (#139)

### Upgrade notes
- No breaking API changes in this release. Switchblade now requires
  Go 1.24.6 or newer (`go.mod`). Consuming buildpacks on an older Go
  toolchain, with automatic toolchain switching disabled, must update
  their toolchain before running
  `go get github.com/cloudfoundry/switchblade@latest`.
- If a consuming buildpack's own `go.mod` also requires `packit/v2`
  directly, check its pinned version against the Go-1.24 ceiling noted
  above before bumping, to avoid an unplanned toolchain/lint bump.
- Docker platform behavior changes without configuration: buildpack
  tarballs are shared across apps and staging uses `gzip -1`. Neither
  can be switched off.
- `SWITCHBLADE_SKIP_BUILD_CACHE` is inert unless a buildpack's CI
  pipeline sets it. Enable it only if no test relies on build cache reuse.
