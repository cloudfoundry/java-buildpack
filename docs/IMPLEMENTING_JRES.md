# Implementing JREs

This guide explains how to implement new JRE providers for the Cloud Foundry Java Buildpack.

## Table of Contents

- [Overview](#overview)
- [Available JRE Providers](#available-jre-providers)
- [JRE Interface](#jre-interface)
- [BaseJRE — Shared Implementation](#basejre--shared-implementation)
- [Implementation Steps](#implementation-steps)
- [Examples](#examples)
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

`BaseJRE.Detect()` calls `DetectJREByEnv(jreKey)` which returns `true` when:
- `JBP_CONFIG_<JREKEY>_JRE` is set, or
- `JBP_CONFIG_COMPONENTS` names this JRE, or
- `BP_JAVA_<JREKEY>` is set

Replace `<JREKEY>` with the uppercased `jreKey` value.

### Running tests

```bash
# JRE unit tests only
.bin/ginkgo -r -mod vendor src/java/jres/

# Full unit suite
bash scripts/unit.sh
```

## Troubleshooting

**`findJavaHome` fails** — the tarball extracted to a directory that matches neither `dirPrefixes` nor `dirExacts`. Check the extraction layout:

```bash
tar tf my-jre.tar.gz | head -5
```

Add the top-level directory prefix/name to `dirPrefixes`/`dirExacts` accordingly.

**Install fails with "No matching dependency"** — check the `jreKey` in `newBaseJRE` matches the `name:` field in `manifest.yml` exactly.

**`extraFinalizeOpts` not applied** — ensure the function is set on `b` (the `BaseJRE` value) before wrapping it: `b.extraFinalizeOpts = func() string { ... }`. Setting it on the returned struct after `return &MyJRE{b}` has no effect.
