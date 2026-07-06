# Implementing JREs

This guide explains how to implement new JRE providers for the Cloud Foundry Java Buildpack.

## Table of Contents

- [Overview](#overview)
- [Available JRE Providers](#available-jre-providers)
- [JRE Interface](#jre-interface)
- [BaseJRE — Shared Implementation](#basejre--shared-implementation)
- [Implementation Steps](#implementation-steps)
- [Examples](#examples)
- [Helper Functions](#helper-functions)
- [Runtime Components](#runtime-components)
- [Testing JREs](#testing-jres)
- [Troubleshooting](#troubleshooting)

## Overview

A JRE provider:

1. **Detects** when it should be used (env vars / config)
2. **Supplies** the Java runtime (download + extract)
3. **Finalizes** configuration (JAVA_HOME, JVM options)

`Supply()`, `Finalize()`, memory calculator, and JVMKill agent are all handled by `BaseJRE`. Implementing a new JRE is typically **14 lines**.

## Available JRE Providers

| Provider | Key | Default | `dirPrefixes` / `dirExacts` |
|----------|-----|---------|------------------------------|
| **OpenJDK** | `openjdk` | Yes (fallback) | `["jdk", "jre"]` |
| **Zulu** | `zulu` | No | `["zulu"]` |
| **GraalVM** | `graalvm` | No | `["graalvm"]` |
| **IBM JRE** | `ibm` | No | prefixes: `["ibm-java"]`, exacts: `["jre"]` |
| **Oracle JRE** | `oracle` | No | `["jdk", "jre"]` |
| **SapMachine** | `sapmachine` | No | `["sapmachine"]` |
| **Azul Platform Prime** | `zing` | No | (custom — does not use `BaseJRE`) |

## JRE Interface

All providers implement `jres.JRE` (`src/java/jres/jre.go`):

```go
type JRE interface {
    Name()     string
    Detect()   (bool, error)
    Supply()   error
    Finalize() error
    JavaHome() string
    Version()  string
    // MemoryCalculatorCommand returns the shell snippet prepended to the
    // container startup command; "" when the memory calculator is not installed.
    MemoryCalculatorCommand() string
}
```

Providers receive a `*common.Context` with shared dependencies (stager, manifest, installer, logger).

## BaseJRE — Shared Implementation

`BaseJRE` (`src/java/jres/base_jre.go`) provides the full `Supply()`/`Finalize()` implementation. Concrete JREs embed it and inject variation via constructor fields — **never override `Supply` or `Finalize`**.

### Variation points

| Field | Type | Purpose |
|-------|------|---------|
| `jreName` | `string` | Display name in logs (e.g. `"OpenJDK"`) |
| `jreKey` | `string` | Manifest key and env detection (e.g. `"openjdk"`) |
| `dirPrefixes` | `[]string` | Directory name prefixes for `findJavaHome()` (e.g. `["jdk", "jre"]`) |
| `dirExacts` | `[]string` | Exact directory names for `findJavaHome()` (e.g. `["jre"]` for IBM) |
| `installErrNote` | `string` | Extra context appended to install error (e.g. GraalVM repo hint) |
| `extraFinalizeOpts` | `func() string` | JRE-specific JVM opts written during `Finalize()` (e.g. `-XX:ActiveProcessorCount=$(nproc)`) |

### What BaseJRE handles automatically

- Download and extraction via `ctx.Installer.InstallDependency`
- `findJavaHome()` — scans `dirPrefixes` / `dirExacts` then falls back to `jreDir` itself
- `profile.d/java.sh` — exports `JAVA_HOME` at runtime
- `JAVA_HOME` env file and `bin/java` dependency link
- JVMKill agent (`Supply` + `Finalize`)
- Memory calculator (`Supply` + `Finalize`)
- Base JVM opts (`-Djava.io.tmpdir=$TMPDIR`)
- `extraFinalizeOpts` (if set)

## Implementation Steps

### Step 1: Create `src/java/jres/<name>.go`

```go
package jres

import "github.com/cloudfoundry/java-buildpack/src/java/common"

// MyJRE implements the JRE interface for My JRE.
type MyJRE struct{ BaseJRE }

// NewMyJRE creates a new My JRE provider.
func NewMyJRE(ctx *common.Context) *MyJRE {
    b := newBaseJRE(ctx, "My JRE", "my-jre", []string{"myjre"}, nil, "")
    b.extraFinalizeOpts = func() string { return "-XX:ActiveProcessorCount=$(nproc)" }
    return &MyJRE{b}
}
```

Set `extraFinalizeOpts` only if you need JRE-specific JVM flags. Omit it (or set to `nil`) if none are needed.

### Step 2: Add dependency to `manifest.yml`

```yaml
- name: my-jre
  version: 1.2.3
  uri: https://example.com/my-jre-1.2.3.tar.gz
  sha256: <sha256>
  cf_stacks:
    - cflinuxfs4
    - cflinuxfs5
```

Also add to `default_versions` if it should be the default for a stack:

```yaml
- name: my-jre
  version: 1.x
```

### Step 3: Register in `src/java/supply/supply.go`

```go
jreRegistry.Register(jres.NewMyJRE(ctx))
```

That is all that is required.

## Examples

### Standard JRE (OpenJDK)

Tarball extracts to a `jdk-*` or `jre-*` subdirectory. `dirPrefixes` covers both.

```go
// src/java/jres/openjdk.go
type OpenJDKJRE struct{ BaseJRE }

func NewOpenJDKJRE(ctx *common.Context) *OpenJDKJRE {
    b := newBaseJRE(ctx, "OpenJDK", "openjdk", []string{"jdk", "jre"}, nil, "")
    b.extraFinalizeOpts = func() string { return "-XX:ActiveProcessorCount=$(nproc)" }
    return &OpenJDKJRE{b}
}
```

### JRE with exact directory name (IBM JRE)

IBM JRE tarball may extract to a directory named `jre` exactly, or to `ibm-java-*`. Both patterns covered:

```go
// src/java/jres/ibm.go
type IBMJRE struct{ BaseJRE }

func NewIBMJRE(ctx *common.Context) *IBMJRE {
    b := newBaseJRE(ctx, "IBM JRE", "ibm", []string{"ibm-java"}, []string{"jre"}, "")
    b.extraFinalizeOpts = func() string { return "-Xtune:virtualized -Xshareclasses:none" }
    return &IBMJRE{b}
}
```

### JRE with install error hint (GraalVM)

GraalVM is not in the default manifest and requires `repository_root` config. The hint appears in the error if installation fails:

```go
// src/java/jres/graalvm.go
type GraalVMJRE struct{ BaseJRE }

func NewGraalVMJRE(ctx *common.Context) *GraalVMJRE {
    b := newBaseJRE(ctx, "GraalVM", "graalvm", []string{"graalvm"}, nil,
        "(ensure repository_root is configured)")
    b.extraFinalizeOpts = func() string { return "-XX:ActiveProcessorCount=$(nproc)" }
    return &GraalVMJRE{b}
}
```

### JRE without extra JVM opts

If no JRE-specific opts are needed, omit `extraFinalizeOpts`:

```go
type MinimalJRE struct{ BaseJRE }

func NewMinimalJRE(ctx *common.Context) *MinimalJRE {
    b := newBaseJRE(ctx, "Minimal JRE", "minimal", []string{"jre"}, nil, "")
    // extraFinalizeOpts left nil — BaseJRE writes only -Djava.io.tmpdir=$TMPDIR
    return &MinimalJRE{b}
}
```

## Testing JREs

Tests live in `src/java/jres/`. Use `standard_jres_test.go` as a reference — it tests all `BaseJRE`-based providers with shared helpers.

### Unit test pattern

```go
var _ = Describe("MyJRE", func() {
    var (
        ctx    *common.Context
        myJRE  *jres.MyJRE
        // ... temp dirs
    )

    BeforeEach(func() {
        // set up ctx with temp dirs and mock manifest
        myJRE = jres.NewMyJRE(ctx)
    })

    It("detects when JBP_CONFIG_MY_JRE is set", func() {
        os.Setenv("JBP_CONFIG_MY_JRE", "{}")
        defer os.Unsetenv("JBP_CONFIG_MY_JRE")
        detected, err := myJRE.Detect()
        Expect(err).NotTo(HaveOccurred())
        Expect(detected).To(BeTrue())
    })
})
```

### Detection

`BaseJRE.Detect()` calls `DetectJREByEnv(jreKey)` which returns `true` when **either**:
- the documented `JBP_CONFIG_<NAME>_JRE` name is set (e.g. `JBP_CONFIG_OPEN_JDK_JRE`) — the **recommended** form, defined for each built-in provider in the `jreNameToDocumentedEnvVar` map, or
- the auto-generated `JBP_CONFIG_<KEY>` alias is set — `jreKey` uppercased with `-` → `_` (e.g. `JBP_CONFIG_OPENJDK`).

The documented `_JRE` names originate from the Ruby buildpack and are kept for backward compatibility, but they remain the recommended, fully-supported form: the buildpack points users to them, and (unlike the auto-generated alias) they also drive memory-calculator config. `JBP_CONFIG_COMPONENTS` is **deprecated** and is not used for JRE selection; there is no `BP_JAVA_<JREKEY>` detection variable.

A **new custom JRE** responds only to the auto-generated `JBP_CONFIG_<KEY>` name unless you add an entry to `jreNameToDocumentedEnvVar`.

### Running tests

```bash
# JRE unit tests only
.bin/ginkgo -r -mod vendor src/java/jres/

# Full unit suite
bash scripts/unit.sh
```

## Helper Functions

These are available in `src/java/jres/` and called by `BaseJRE` internally. You may need them if you implement a JRE that does not use `BaseJRE` (e.g. Zing).

| Function | Purpose |
|----------|---------|
| `GetJREVersion(ctx, jreKey)` | Resolves version from `BP_JAVA_VERSION`, then the documented `JBP_CONFIG_<NAME>_JRE` or auto-generated `JBP_CONFIG_<KEY>` alias, then manifest default |
| `DetectJREByEnv(jreKey)` | Returns `true` if the documented `JBP_CONFIG_<NAME>_JRE` name or the auto-generated `JBP_CONFIG_<KEY>` alias selects this JRE |
| `WriteJavaHomeProfileD(ctx, jreDir, javaHome)` | Writes `profile.d/java.sh` exporting `JAVA_HOME`, `JRE_HOME`, and `PATH` |
| `WriteJavaOpts(ctx, opts)` | Appends opts to the centralized `.opts` file consumed by `profile.d/00_java_opts.sh` |
| `common.DetermineJavaVersion(javaHome)` | Reads `$JAVA_HOME/release` → returns Java major version as int |

### Version resolution priority

1. `BP_JAVA_VERSION` (e.g. `21`, `21.*`, `21.0.5`)
2. The documented `JBP_CONFIG_<NAME>_JRE` name, or the auto-generated `JBP_CONFIG_<KEY>` alias, with a `version:` field
3. Manifest `default_versions` entry for this JRE key

### profile.d output

`WriteJavaHomeProfileD` produces `$DEPS_DIR/<idx>/.profile.d/java.sh`:

```bash
export JAVA_HOME=$DEPS_DIR/0/jre/jdk-21.0.5
export JRE_HOME=$DEPS_DIR/0/jre/jdk-21.0.5
export PATH=$JAVA_HOME/bin:$PATH
```

## Runtime Components

`BaseJRE` installs and finalizes these automatically. Documented here for operational reference.

### Memory Calculator

Downloads `java-buildpack-memory-calculator` binary. At application start it computes JVM heap/metaspace/stack settings from `$MEMORY_LIMIT`:

```
-Xmx512M -Xms512M -XX:MaxMetaspaceSize=128M -Xss1M -XX:ReservedCodeCacheSize=32M
```

User customization — prefer `JBP_CONFIG_<JRE>_JRE` for structured config (covers all three knobs):

```bash
cf set-env myapp JBP_CONFIG_OPEN_JDK_JRE \
  '{memory_calculator: {stack_threads: 300, class_count: 500, headroom: 10}}'
```

`stack_threads` — number of user threads (default: 200); affects `-Xss` heap budget.
`class_count` — estimated loaded classes (default: auto-detected); affects `-XX:MaxMetaspaceSize`.
`headroom` — percent of total memory to leave unallocated (default: 0).

`MEMORY_CALCULATOR_*` env vars are a simpler alternative, but only cover two of the three knobs. They take precedence over `JBP_CONFIG_*` when both are set:

```bash
cf set-env myapp MEMORY_CALCULATOR_STACK_THREADS 300
cf set-env myapp MEMORY_CALCULATOR_HEADROOM 10
# class_count not available as a MEMORY_CALCULATOR_* env var — use JBP_CONFIG_* for that
```

### JVMKill Agent

Native agent (`.so`) that kills the JVM on `OutOfMemoryError` or memory allocation failure, causing CF to restart the container cleanly instead of hanging.

Added to `JAVA_OPTS` as:
```
-agentpath:/home/vcap/deps/0/jre/bin/jvmkill-1.16.0.so=printHeapHistogram=1
```

**Heap dump support:** if a volume service tagged `heap-dump` is bound, JVMKill writes heap dumps to the mounted volume:

```bash
cf bind-service myapp my-nfs -c '{"mount":"/volumes/heap-dumps","tags":["heap-dump"]}'
```

## Troubleshooting

**`findJavaHome` fails** — tarball extracted to directory matching neither `dirPrefixes` nor `dirExacts`. Check layout:

```bash
tar tf my-jre.tar.gz | head -5
```

Add the top-level directory prefix/name to `dirPrefixes`/`dirExacts` accordingly.

**Install fails with "No matching dependency"** — `jreKey` in `newBaseJRE` must match the `name:` field in `manifest.yml` exactly.

**`extraFinalizeOpts` not applied** — set the function on `b` (the `BaseJRE` value) before wrapping: `b.extraFinalizeOpts = func() string { ... }`. Setting it after `return &MyJRE{b}` has no effect.

**JAVA_HOME not set at runtime** — verify `profile.d/java.sh` exists:

```bash
cf ssh myapp -- cat /home/vcap/deps/0/.profile.d/java.sh
```

**Memory calculator not running** — verify binary exists and `MEMORY_LIMIT` is set:

```bash
cf ssh myapp -- ls /home/vcap/deps/0/jre/bin/java-buildpack-memory-calculator-*
cf ssh myapp -- echo $MEMORY_LIMIT
```

**Wrong Java version selected** — check resolution order: `BP_JAVA_VERSION` → `JBP_CONFIG_<KEY>_JRE` → manifest default. Enable debug: `cf set-env myapp BP_LOG_LEVEL DEBUG`.

## Summary

Adding a standard JRE (one that embeds `BaseJRE`) requires three things:

1. **Create `src/java/jres/<name>.go`** — embed `BaseJRE`, call `newBaseJRE()`, set `extraFinalizeOpts` if needed
2. **Add dependency to `manifest.yml`** — `name`, version, URI, SHA256, stacks; add to `default_versions` if applicable
3. **Register in `src/java/supply/supply.go`** — one `jreRegistry.Register(jres.NewMyJRE(ctx))` call

`BaseJRE` handles everything else: download, extraction, `findJavaHome`, `profile.d` script, JVMKill, Memory Calculator, base JVM opts.

For JREs that cannot use `BaseJRE` (e.g. Zing — no memory calculator, custom detection), implement the full `jres.JRE` interface manually and use the helper functions listed above.

## See Also

- [DEVELOPING.md](DEVELOPING.md) — building and running the buildpack locally
- [TESTING.md](TESTING.md) — unit and integration test framework
- [IMPLEMENTING_FRAMEWORKS.md](IMPLEMENTING_FRAMEWORKS.md) — adding framework support
- [IMPLEMENTING_CONTAINERS.md](IMPLEMENTING_CONTAINERS.md) — adding container types
