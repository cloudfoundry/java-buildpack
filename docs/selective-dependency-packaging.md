# Selective Dependency Packaging

**Status**: Proposed  
**Date**: 2026-04-01  
**Affects**: `libbuildpack/packager`, all CF buildpacks

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Goals and Non-Goals](#2-goals-and-non-goals)
3. [Current Architecture](#3-current-architecture)
4. [Proposed Architecture](#4-proposed-architecture)
5. [Design Decisions](#5-design-decisions)
6. [manifest.yml Changes](#6-manifestyml-changes)
7. [libbuildpack/packager Changes](#7-libbuildpackpackager-changes)
8. [scripts/package.sh Changes](#8-scriptspackagesh-changes)
9. [java-buildpack Adoption](#9-java-buildpack-adoption)
10. [Implementation Plan](#10-implementation-plan)
11. [Testing Strategy](#11-testing-strategy)
12. [Rollout Strategy](#12-rollout-strategy)
13. [Open Questions](#13-open-questions)

---

## 1. Problem Statement

Running `scripts/package.sh --cached` produces an **offline buildpack** — a zip that contains every
dependency declared in `manifest.yml`. For the java-buildpack this means 47 binaries are bundled,
covering every JRE distribution, every APM agent, every profiler, and every JDBC driver, regardless
of whether the target platform will ever use them.

**Concrete consequences**:

- The resulting zip is very large, making it slow to upload and store.
- Air-gapped environments that only use, say, OpenJDK + Tomcat are forced to carry agents for
  Datadog, New Relic, JRebel, YourKit, SkyWalking, and dozens of other tools they will never need.
- Operators cannot tailor a buildpack to their security posture (e.g., excluding a commercial agent
  they don't have a license for).

**This is not a java-buildpack-only problem.** Eight of the thirteen CF buildpacks have ten or more
dependencies (python: 23, ruby: 22, dotnet-core: 20, php: 16, go: 13, nginx: 12, nodejs: 11) and
face the same trade-off when building cached/offline releases.

---

## 2. Goals and Non-Goals

### Goals

- Allow operators to build a cached buildpack that contains only a **named subset** of dependencies.
- Support both **ad-hoc exclusion** (`--exclude dep-a,dep-b`) and **named profiles** (`--profile minimal`).
- Profiles are declared inside `manifest.yml` of each buildpack — no global registry needed.
- The feature lives in **`libbuildpack/packager`** so every buildpack inherits it automatically.
- **Fully backward compatible**: buildpacks that do not use the new flags are completely unaffected.

### Non-Goals

- Runtime dependency filtering (what the running buildpack installs for an app) — this is purely a
  *packaging-time* concern.
- Changing how `buildpack-packager` handles stacks — that mechanism is orthogonal and unchanged.
- Automatic profile selection based on platform configuration.
- A centralised profile registry shared across buildpacks.

---

## 3. Current Architecture

### 3.1 Packaging pipeline (today)

```
scripts/package.sh --cached
  └─ buildpack-packager build
         --version=<v>
         --cached=true
         --stack=cflinuxfs4
       └─ packager.Package(bpDir, cacheDir, version, stack, cached=true)
            ├─ validates stack against manifest
            ├─ runs pre_package script
            ├─ for every dependency that matches the stack:
            │    ├─ downloadDependency()   ← downloads ALL deps
            │    └─ SHA256 verify
            └─ ZipFiles() → java_buildpack-cached-cflinuxfs4-v<v>.zip
```

### 3.2 Dependency declaration in manifest.yml (today)

```yaml
dependencies:
  - name: datadog-javaagent
    version: 1.42.1
    uri: https://repo1.maven.org/...
    sha256: e703547f...
    cf_stacks:
      - cflinuxfs4
```

Each dependency entry has: `name`, `version`, `uri`, `sha256`, `cf_stacks`.  
There is no concept of optionality, grouping, or profiles.

### 3.3 Shared scripts

`scripts/package.sh` and `scripts/.util/tools.sh` are **byte-for-byte identical** across all 13
buildpacks (differing only in the default `stack=` value). Any new flag added to `buildpack-packager`
needs only a trivial one-line change in the shared script template to become available everywhere.

---

## 4. Proposed Architecture

### 4.1 Overview

Two complementary mechanisms are added, both optional:

| Mechanism | Flag | Where defined | Use case |
|---|---|---|---|
| Ad-hoc exclusion | `--exclude dep-a,dep-b` | CLI only | One-off builds, CI overrides |
| Named profiles | `--profile minimal` | `manifest.yml` | Reusable, versioned subsets |

Both are purely *packaging-time* filters. At runtime the buildpack behaves identically — components
that rely on a dependency that was excluded simply will not find it and will not activate (the same
as they would in an uncached buildpack where the network is unavailable).

### 4.2 End-to-end flow (proposed)

```
scripts/package.sh --cached --profile minimal
  └─ buildpack-packager build
         --version=<v>
         --cached=true
         --stack=cflinuxfs4
         --profile=minimal          ← NEW
       └─ packager.Package(bpDir, cacheDir, version, stack, cached=true,
                           exclude=["datadog-javaagent","newrelic",...])
            ├─ resolveExclusions(manifest, profile="minimal", exclude=[])
            │    └─ returns []string of dep names to skip
            ├─ for every dependency that matches the stack AND is not excluded:
            │    ├─ downloadDependency()   ← only selected deps
            │    └─ SHA256 verify
            └─ ZipFiles() → java_buildpack-cached-cflinuxfs4-v<v>.zip
```

### 4.3 Zip filename convention

The output filename gains a profile or exclusion suffix so that different variants can coexist:

| Invocation | Output filename |
|---|---|
| `--cached` | `java_buildpack-cached-cflinuxfs4-v1.2.3.zip` |
| `--cached --profile minimal` | `java_buildpack-cached-cflinuxfs4-minimal-v1.2.3.zip` |
| `--cached --exclude newrelic` | `java_buildpack-cached-cflinuxfs4-custom-v1.2.3.zip` |

---

## 5. Design Decisions

### 5.1 Why profiles live in manifest.yml, not a separate file

`manifest.yml` is already the single source of truth for dependency metadata. Keeping profiles there
means:

- Profile definitions are versioned alongside the dependencies they reference.
- `buildpack-packager summary` can be extended to also list profiles.
- No new file format needs to be discovered or parsed by tooling.

### 5.2 Why `--exclude` takes dependency *names* not *indices*

Names are stable across manifest updates. Indices change whenever a dependency is added or removed.
Using names also makes CI scripts and documentation self-documenting.

### 5.3 Why profiles use `exclude` lists rather than `include` lists

The manifest already declares the full set of available dependencies. Exclusion lists are shorter
and require less maintenance: when a new optional dependency is added to the manifest it is
automatically part of all profiles unless explicitly excluded. An inclusion-based profile would
require every profile to be updated each time a new core dependency is added.

The `minimal` profile is the one exception that benefits most from this: it excludes the long tail
of optional agents, and the "include everything" case is simply the absence of any profile.

### 5.4 Why the feature belongs in libbuildpack, not per-buildpack scripts

All buildpacks share the same `buildpack-packager` binary (installed via `go install ...@latest`).
Adding the feature to the packager makes it available to every buildpack immediately, with only a
trivial script change per buildpack to expose the new flags. The alternative — implementing YAML
manipulation in each buildpack's `package.sh` — would be duplicated across 13 repos and harder to
keep consistent.

### 5.5 Mutual exclusion: --profile and --exclude can be combined

`--profile minimal --exclude groovy` is valid. The profile's exclusion list is computed first, then
the `--exclude` list is unioned with it. This allows operators to start from a profile and trim
further for a specific deployment.

### 5.6 Unknown dependency names are errors

If `--exclude datadog-javaagent` is passed but `datadog-javaagent` does not exist in the manifest,
`buildpack-packager` exits non-zero. This catches typos early rather than silently producing a zip
that happens to be missing something unexpected.

Same rule applies to profiles: referencing an unknown profile name is a hard error.

---

## 6. manifest.yml Changes

### 6.1 New top-level field: `packaging_profiles`

```yaml
# manifest.yml (excerpt — new section added near the top)

packaging_profiles:
  minimal:
    description: "JDKs and core CF utilities only. No APM agents, profilers, or JDBC drivers."
    exclude:
      - datadog-javaagent
      - elastic-apm-agent
      - azure-application-insights
      - skywalking-agent
      - splunk-otel-javaagent
      - google-stackdriver-profiler
      - open-telemetry-javaagent
      - contrast-security
      - newrelic
      - sealights-agent
      - jacoco
      - jrebel
      - your-kit-profiler
      - jprofiler-profiler
      - java-memory-assistant
      - java-memory-assistant-cleanup
      - luna-security-provider
      - postgresql-jdbc
      - mariadb-jdbc

  standard:
    description: "Core + open-source APM/observability. No commercial profilers or security providers."
    exclude:
      - jrebel
      - your-kit-profiler
      - jprofiler-profiler
      - contrast-security
      - sealights-agent
      - luna-security-provider
      - java-memory-assistant
      - java-memory-assistant-cleanup
```

No changes to the `dependencies:` entries themselves. Existing dependency declarations remain
unchanged so that the full set is still packaged when no profile or exclude flag is given.

### 6.2 YAML schema for packaging_profiles

```
packaging_profiles:
  <profile-name>:          # string, no spaces, used as CLI value
    description: <string>  # human-readable, shown in --help / summary
    exclude:               # list of dependency names (must exist in manifest)
      - <dep-name>
      - ...
```

---

## 7. libbuildpack/packager Changes

### 7.1 models.go — new struct fields

```go
// PackagingProfile defines a named dependency exclusion set for use at packaging time.
type PackagingProfile struct {
    Description string   `yaml:"description"`
    Exclude     []string `yaml:"exclude"`
}

// Manifest — add PackagingProfiles field
type Manifest struct {
    Language         string                       `yaml:"language"`
    Stack            string                       `yaml:"stack"`
    IncludeFiles     []string                     `yaml:"include_files"`
    PrePackage       string                       `yaml:"pre_package"`
    Dependencies     Dependencies                 `yaml:"dependencies"`
    Defaults         []struct {
        Name    string `yaml:"name"`
        Version string `yaml:"version"`
    } `yaml:"default_versions"`
    PackagingProfiles map[string]PackagingProfile `yaml:"packaging_profiles"` // NEW
}
```

### 7.2 packager.go — exclusion resolution and filtering

New unexported helper `resolveExclusions`:

```go
// resolveExclusions returns the set of dependency names that should be skipped
// during packaging. It merges the profile's exclude list (if a profile is named)
// with any explicitly passed exclude names. An error is returned if the profile
// name is unknown or if any exclude name does not exist in the manifest.
func resolveExclusions(manifest Manifest, profile string, exclude []string) (map[string]struct{}, error) {
    // 1. Start with explicitly excluded names
    result := make(map[string]struct{})
    for _, name := range exclude {
        result[name] = struct{}{}
    }

    // 2. If a profile is named, merge its exclude list
    if profile != "" {
        p, ok := manifest.PackagingProfiles[profile]
        if !ok {
            return nil, fmt.Errorf("packaging profile %q not found in manifest", profile)
        }
        for _, name := range p.Exclude {
            result[name] = struct{}{}
        }
    }

    // 3. Validate: every name must exist in the manifest
    depNames := make(map[string]struct{})
    for _, d := range manifest.Dependencies {
        depNames[d.Name] = struct{}{}
    }
    for name := range result {
        if _, ok := depNames[name]; !ok {
            return nil, fmt.Errorf("excluded dependency %q not found in manifest", name)
        }
    }

    return result, nil
}
```

Updated `Package` signature:

```go
// Package creates a cached or uncached buildpack zip.
//
// New parameters compared to the previous signature:
//   profile: name of a packaging_profiles entry in manifest.yml (empty = no profile)
//   exclude: additional dependency names to skip regardless of profile
func Package(bpDir, cacheDir, version, stack string, cached bool, profile string, exclude []string) (string, error) {
```

Updated inner dependency loop (the only logic change inside `Package`):

```go
    // Resolve which deps to skip BEFORE the download loop
    excluded, err := resolveExclusions(manifest, profile, exclude)
    if err != nil {
        return "", err
    }

    for idx, d := range manifest.Dependencies {
        // Skip excluded dependencies entirely — they are not downloaded
        // and are not written into the packaged manifest.yml
        if _, skip := excluded[d.Name]; skip {
            continue
        }

        for _, s := range d.Stacks {
            if stack == "" || s == stack {
                dependencyMap := deps[idx]
                if cached {
                    if file, err := downloadDependency(d, cacheDir); err != nil {
                        return "", err
                    } else {
                        updateDependencyMap(dependencyMap, file)
                        files = append(files, file)
                    }
                }
                if stack != "" {
                    delete(dependencyMap.(map[interface{}]interface{}), "cf_stacks")
                }
                dependenciesForStack = append(dependenciesForStack, dependencyMap)
                break
            }
        }
    }
```

Filename suffix logic (appended after the existing `cachedPart` / `stackPart` computation):

```go
    profilePart := ""
    if profile != "" {
        profilePart = "-" + profile
    } else if len(exclude) > 0 {
        profilePart = "-custom"
    }

    fileName := fmt.Sprintf(
        "%s_buildpack%s%s%s-v%s.zip",
        manifest.Language, cachedPart, profilePart, stackPart, version,
    )
```

### 7.3 buildpack-packager/main.go — new CLI flags

```go
type buildCmd struct {
    cached   bool
    anyStack bool
    version  string
    cacheDir string
    stack    string
    profile  string   // NEW
    exclude  string   // NEW: comma-separated, parsed before calling Package
}

func (b *buildCmd) SetFlags(f *flag.FlagSet) {
    f.StringVar(&b.version,  "version",  "", "version to build as")
    f.BoolVar(&b.cached,     "cached",   false, "include dependencies")
    f.StringVar(&b.cacheDir, "cachedir", packager.CacheDir, "cache dir")
    f.StringVar(&b.stack,    "stack",    "", "stack to package buildpack for")
    f.BoolVar(&b.anyStack,   "any-stack", false, "package buildpack for any stack")
    f.StringVar(&b.profile,  "profile",  "", "packaging profile defined in manifest.yml")   // NEW
    f.StringVar(&b.exclude,  "exclude",  "", "comma-separated dependency names to exclude") // NEW
}

func (b *buildCmd) Execute(_ context.Context, f *flag.FlagSet, _ ...interface{}) subcommands.ExitStatus {
    // ... existing validation ...

    // Parse exclude list
    var excludeList []string
    if b.exclude != "" {
        for _, name := range strings.Split(b.exclude, ",") {
            name = strings.TrimSpace(name)
            if name != "" {
                excludeList = append(excludeList, name)
            }
        }
    }

    zipFile, err := packager.Package(".", b.cacheDir, b.version, b.stack, b.cached,
        b.profile, excludeList) // NEW parameters
    // ... rest unchanged ...
}
```

Updated `Usage()` string:

```
build -stack <stack>|-any-stack [-cached] [-version <version>]
      [-cachedir <path>] [-profile <profile>] [-exclude <dep1,dep2,...>]:

  Creates a zip file from the current buildpack directory.

  -profile  Name of a packaging profile defined in manifest.yml's
            packaging_profiles section. Profiles declare which dependencies
            to exclude from the cached zip.

  -exclude  Comma-separated list of dependency names to exclude, in addition
            to any exclusions implied by -profile. Names must exist in
            manifest.yml. Example: -exclude datadog-javaagent,newrelic
```

### 7.4 summary.go — list available profiles

The `buildpack-packager summary` subcommand should be extended to print available profiles when the
manifest contains a `packaging_profiles` section:

```
Packaged binaries:
...

Default binary versions:
...

Packaging profiles:
  minimal   JDKs and core CF utilities only. No APM agents, profilers, or JDBC drivers.
  standard  Core + open-source APM/observability. No commercial profilers or security providers.
```

Implementation: iterate `manifest.PackagingProfiles` in sorted key order, print name + description.

### 7.5 Backward compatibility

The new `profile` and `exclude` parameters are added at the **end** of the `Package()` signature.
All existing callers (other buildpack tests and tools that call `packager.Package` directly) must
be updated to pass empty values:

```go
// Before
packager.Package(bpDir, cacheDir, version, stack, cached)

// After
packager.Package(bpDir, cacheDir, version, stack, cached, "", nil)
```

Since `libbuildpack` is a Go module consumed via `go install ...@latest`, this is a breaking change
to the Go API. Two options:

**Option A — Update signature, update all callers in the same PR.**  
Clean, no shims. Requires coordinating one PR across `libbuildpack` and any internal tooling that
calls `Package()` directly (currently only `buildpack-packager/main.go` and test files in
`libbuildpack` itself).

**Option B — Introduce a new function `PackageWithOptions`.**  
```go
type PackageOptions struct {
    Profile string
    Exclude []string
}

func PackageWithOptions(bpDir, cacheDir, version, stack string, cached bool, opts PackageOptions) (string, error)

// Package delegates to PackageWithOptions with zero-value opts for backward compat
func Package(bpDir, cacheDir, version, stack string, cached bool) (string, error) {
    return PackageWithOptions(bpDir, cacheDir, version, stack, cached, PackageOptions{})
}
```

**Recommendation**: Option B. It keeps the existing `Package()` function intact and avoids a
flag day across all consumers.

---

## 8. scripts/package.sh Changes

Each buildpack's `scripts/package.sh` needs two additions:

1. Parse `--profile` and `--exclude` in the `while` loop.
2. Forward them to `buildpack-packager`.

```bash
function main() {
  local stack version cached output profile exclude
  stack="cflinuxfs4"
  cached="false"
  output="${ROOTDIR}/build/buildpack.zip"
  profile=""     # NEW
  exclude=""     # NEW

  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      # ... existing cases unchanged ...

      --profile)          # NEW
        profile="${2}"
        shift 2
        ;;

      --exclude)          # NEW
        exclude="${2}"
        shift 2
        ;;

      # ...
    esac
  done

  package::buildpack "${version}" "${cached}" "${stack}" "${output}" "${profile}" "${exclude}"
}

function package::buildpack() {
  local version cached stack output profile exclude
  version="${1}"
  cached="${2}"
  stack="${3}"
  output="${4}"
  profile="${5}"   # NEW
  exclude="${6}"   # NEW

  # ... existing setup ...

  local profile_flag="" exclude_flag=""
  [[ -n "${profile}" ]] && profile_flag="--profile=${profile}"
  [[ -n "${exclude}" ]] && exclude_flag="--exclude=${exclude}"

  local file
  file="$(
    "${ROOTDIR}/.bin/buildpack-packager" build \
      "--version=${version}" \
      "--cached=${cached}" \
      "${stack_flag}" \
      ${profile_flag:+"${profile_flag}"} \
      ${exclude_flag:+"${exclude_flag}"} \
    | xargs -n1 | grep -e '\.zip$'
  )"

  mv "${file}" "${output}"
}
```

Updated `usage()`:

```
package.sh --version <version> [OPTIONS]
Packages the buildpack into a .zip file.
OPTIONS
  --help               -h            prints the command usage
  --version <version>                specifies the version number
  --cached                           bundle dependencies (default: false)
  --stack  <stack>                   target stack (default: cflinuxfs4)
  --output <file>                    output path (default: build/buildpack.zip)
  --profile <name>                   packaging profile from manifest.yml
  --exclude <dep1,dep2,...>          additional dependencies to exclude
```

---

## 9. java-buildpack Adoption

### 9.1 manifest.yml profiles

The following profiles are proposed for the java-buildpack. The dependency categorisation used
here mirrors the analysis of the 47 dependencies in the current `manifest.yml`.

**Core (never excluded by any profile)**:
- JDKs: `openjdk`, `zulu`, `sapmachine` (all versions)
- CF utilities: `jvmkill`, `memory-calculator`, `auto-reconfiguration`, `java-cfenv`,
  `client-certificate-mapper`, `metric-writer`, `container-security-provider`,
  `cf-metrics-exporter`
- Tomcat family: `tomcat`, `tomcat-access-logging-support`, `tomcat-lifecycle-support`,
  `tomcat-logging-support`
- Other frameworks: `groovy`, `spring-boot-cli`

**`minimal` profile** — excludes everything that requires a commercial license or serves a
single vendor's ecosystem:
```yaml
  minimal:
    description: "JDKs, CF utilities, Tomcat, and common frameworks only."
    exclude:
      - datadog-javaagent
      - elastic-apm-agent
      - azure-application-insights
      - skywalking-agent
      - splunk-otel-javaagent
      - google-stackdriver-profiler
      - open-telemetry-javaagent
      - contrast-security
      - newrelic
      - sealights-agent
      - jacoco
      - jrebel
      - your-kit-profiler
      - jprofiler-profiler
      - java-memory-assistant
      - java-memory-assistant-cleanup
      - luna-security-provider
      - postgresql-jdbc
      - mariadb-jdbc
```
Result: 47 → 28 dependencies bundled.

**`standard` profile** — adds open-source observability (OTel, JaCoCo) and JDBC drivers, removes
commercial profilers and specialist security providers:
```yaml
  standard:
    description: "Core + open-source APM, OTel, and JDBC drivers. No commercial agents or profilers."
    exclude:
      - datadog-javaagent
      - elastic-apm-agent
      - azure-application-insights
      - skywalking-agent
      - splunk-otel-javaagent
      - google-stackdriver-profiler
      - contrast-security
      - newrelic
      - sealights-agent
      - jrebel
      - your-kit-profiler
      - jprofiler-profiler
      - java-memory-assistant
      - java-memory-assistant-cleanup
      - luna-security-provider
```
Result: 47 → 32 dependencies bundled.

### 9.2 Typical usage examples

```bash
# Current behaviour — unchanged
./scripts/package.sh --cached

# Air-gapped environment, only OpenJDK + Tomcat needed
./scripts/package.sh --cached --profile minimal

# Standard ops team buildpack — OTel and JDBC included, commercial agents excluded
./scripts/package.sh --cached --profile standard

# Standard profile but also drop jacoco (not needed on this foundation)
./scripts/package.sh --cached --profile standard --exclude jacoco

# One-off: full cached buildpack minus the two agents we don't have licences for
./scripts/package.sh --cached --exclude jrebel,your-kit-profiler,jprofiler-profiler
```

---

## 10. Implementation Plan

The work is broken into three sequential phases. Phases 1 and 2 are in `libbuildpack`, Phase 3 is
in `java-buildpack` (and optionally in other buildpacks).

### Phase 1 — libbuildpack core (packager library)

| # | File | Change | Notes |
|---|---|---|---|
| 1.1 | `packager/models.go` | Add `PackagingProfile` struct and `PackagingProfiles` field on `Manifest` | ~15 lines |
| 1.2 | `packager/packager.go` | Add `resolveExclusions()` helper | ~30 lines |
| 1.3 | `packager/packager.go` | Add `PackageWithOptions` and update `Package` to delegate | ~20 lines |
| 1.4 | `packager/packager.go` | Apply exclusion filter in dependency loop, update filename logic | ~15 lines |
| 1.5 | `packager/summary.go` | Print `packaging_profiles` section in `Summary()` | ~20 lines |
| 1.6 | `packager/packager_test.go` | Test cases for exclude, profile, combined, unknown name errors | ~80 lines |
| 1.7 | `packager/models_test.go` | Test `resolveExclusions` edge cases | ~40 lines |

**Entry criteria**: existing tests pass on `main`.  
**Exit criteria**: all new tests pass, `packager.Package()` signature unchanged, `PackageWithOptions` works.

### Phase 2 — buildpack-packager CLI

| # | File | Change | Notes |
|---|---|---|---|
| 2.1 | `packager/buildpack-packager/main.go` | Add `--profile` and `--exclude` flags to `buildCmd` | ~25 lines |
| 2.2 | `packager/buildpack-packager/main.go` | Parse comma-separated `--exclude` into `[]string` | ~10 lines |
| 2.3 | `packager/buildpack-packager/main.go` | Update `Usage()` string | ~10 lines |

**Exit criteria**: `buildpack-packager build --help` shows new flags; manual smoke test against
java-buildpack `manifest.yml` produces expected zip sizes.

### Phase 3 — java-buildpack adoption

| # | File | Change | Notes |
|---|---|---|---|
| 3.1 | `manifest.yml` | Add `packaging_profiles` section with `minimal` and `standard` | ~40 lines |
| 3.2 | `scripts/package.sh` | Add `--profile` / `--exclude` flag parsing and forwarding | ~15 lines |
| 3.3 | `scripts/package.sh` | Update `usage()` | ~5 lines |

**Exit criteria**:
- `./scripts/package.sh --cached --profile minimal` produces a zip with 28 dependencies.
- `./scripts/package.sh --cached` produces a zip with 47 dependencies (unchanged).
- `buildpack-packager summary` lists the two profiles.

### Phase 4 (optional) — other buildpacks

Any buildpack team can independently add a `packaging_profiles` section to their `manifest.yml`
and the two-line script update to `scripts/package.sh`. No further changes to `libbuildpack` are
required.

---

## 11. Testing Strategy

### Unit tests (libbuildpack)

| Scenario | Expected outcome |
|---|---|
| `Package` called with no profile, no exclude | All stack-matching deps bundled (existing behaviour) |
| `Package` called with `exclude=["dep-a"]` | `dep-a` absent from zip manifest and not downloaded |
| `Package` called with valid `profile="minimal"` | Profile's exclude list applied correctly |
| `Package` called with `profile` + extra `exclude` | Union of both exclude lists applied |
| `Package` called with unknown `profile` name | Returns error containing profile name |
| `Package` called with `exclude` containing unknown dep name | Returns error containing dep name |
| `Package` called with excluded dep that is a default version | Excluded dep is absent; other versions of same name unaffected |
| Zip filename — profile set | Contains `-<profile>` segment |
| Zip filename — exclude only | Contains `-custom` segment |
| Zip filename — neither | Original filename (backward compat) |

New fixture: `packager/fixtures/with_profiles/manifest.yml` — a minimal manifest with a
`packaging_profiles` section used by the new tests.

### Integration / smoke tests (java-buildpack CI)

The existing `ci/package-test.sh` script can be extended to:

1. Build `--profile minimal` and assert the zip does **not** contain `dependencies/*/dd-java-agent*`.
2. Build `--cached` (no profile) and assert the zip **does** contain that file.
3. Build `--exclude datadog-javaagent` and assert the same.

These can run without downloading real binaries by mocking the packager's HTTP client (as the
existing packager tests already do via `httpmock`).

---

## 12. Rollout Strategy

1. **Land Phase 1+2 in `libbuildpack`** as a single PR. Tagging a new release is not strictly
   required because all buildpacks use `@latest`, but a tag is recommended for traceability.

2. **Land Phase 3 in `java-buildpack`** once the `libbuildpack` PR is merged and the binary
   installed at `.bin/buildpack-packager` is refreshed in CI.

3. **Communicate to other buildpack teams** that `--profile` and `--exclude` are now available.
   Each team can adopt on their own schedule by adding `packaging_profiles` to their manifest.

4. **No operator action required** for existing deployments. Operators who build the buildpack
   without `--profile` or `--exclude` get identical output to today.

---

## 13. Open Questions

| # | Question | Options | Decision |
|---|---|---|---|
| Q1 | Should `--exclude` on an uncached buildpack be an error or a no-op? | Error (prevents confusing "I excluded it but the dep is still downloaded at runtime" situation) vs no-op (silently harmless) | Recommend: **no-op with a warning** — exclusion is meaningless for uncached builds but not necessarily a mistake |
| Q2 | Should profile names be validated for character set? (e.g., no spaces, no slashes) | Yes (reject invalid names) vs no | Recommend: **yes**, restrict to `[a-z0-9_-]+` to keep filenames safe |
| Q3 | Should excluded dependencies be completely absent from the packaged `manifest.yml`? | Absent (cleaner, smaller manifest) vs present with a flag | Recommend: **absent** — a smaller manifest also means faster version resolution at staging time |
| Q4 | Should `packaging_profiles` entries be validated at `buildpack-packager summary` time even when not building? | Yes (catches stale exclusion lists) vs no | Recommend: **yes**, warn if a profile excludes a name not in `dependencies` |
| Q5 | Should we also support `include` lists in profiles (whitelist model)? | Yes (more explicit) vs no (requires updating all profiles when a new dep is added) | Recommend: **no for now** — the exclude model is simpler and handles all known use cases; can be added later |
