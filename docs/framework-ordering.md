# Framework Ordering and JAVA_OPTS Priority

## Overview

This document defines the execution order for Java Buildpack frameworks, based on the Ruby buildpack's `config/components.yml` (lines 40-83).

**Critical**: Framework order matters because:
1. Some frameworks modify JVM bootstrap behavior (e.g., Container Security Provider)
2. Some frameworks require native library loading before security modifications (e.g., JRebel)
3. User-defined JAVA_OPTS should override framework defaults (JavaOpts framework runs last)

## Framework Order (Ruby Buildpack `components.yml` Lines 44-82)

**IMPORTANT**: These line numbers from the Ruby buildpack directly map to execution priority.

```
Line | Framework Name                          | Priority | Notes
-----|----------------------------------------|----------|------------------------------------------
44   | MultiBuildpack                         | 10       | Allows overrides from earlier buildpacks
45   | AppDynamicsAgent                       | 11       | APM agent
46   | AspectjWeaverAgent                     | 12       | AOP agent
47   | AzureApplicationInsightsAgent          | 13       | APM agent
48   | CheckmarxIastAgent                     | 14       | Security agent
49   | ClientCertificateMapper                | 15       | Security
50   | ContainerCustomizer                    | 16       | Container modifications
51   | ContainerSecurityProvider              | 17       | ⚠️ Modifies bootclasspath & security
52   | ContrastSecurityAgent                  | 18       | Security agent
53   | DatadogJavaagent                       | 19       | APM agent
54   | Debug                                  | 20       | Debug agent (-agentlib:jdwp)
55   | DynatraceOneAgent                      | 21       | APM agent
56   | ElasticApmAgent                        | 22       | APM agent
57   | GoogleStackdriverDebugger              | 23       | Debugger (commented out)
58   | GoogleStackdriverProfiler              | 24       | Profiler
59   | IntroscopeAgent                        | 25       | APM agent
60   | JacocoAgent                            | 26       | Code coverage agent
61   | JavaCfEnv                              | 27       | Environment configuration
62   | JavaMemoryAssistant                    | 28       | Memory management
63   | Jmx                                    | 29       | JMX configuration
64   | JprofilerProfiler                      | 30       | Profiler
65   | JrebelAgent                            | 31       | ⚠️ Native agent, runs AFTER CSP
66   | LunaSecurityProvider                   | 32       | Security provider
67   | MariaDbJDBC                            | 33       | JDBC driver
68   | MetricWriter                           | 34       | Metrics
69   | NewRelicAgent                          | 35       | APM agent
70   | OpenTelemetryJavaagent                 | 36       | Observability agent
71   | PostgresqlJDBC                         | 37       | JDBC driver
72   | RiverbedAppinternalsAgent              | 38       | APM agent
73   | SealightsAgent                         | 39       | Security agent
74   | SeekerSecurityProvider                 | 40       | Security provider
75   | SpringAutoReconfiguration              | 41       | Spring framework
76   | SplunkOtelJavaAgent                    | 42       | Observability agent
77   | SpringInsight                          | 43       | Spring monitoring
78   | SkyWalkingAgent                        | 44       | APM agent
79   | YourKitProfiler                        | 45       | Profiler
80   | TakipiAgent                            | 46       | APM agent
81   | JavaSecurity                           | 47       | Security configuration
82   | JavaOpts                               | 99       | ⚠️ USER-DEFINED OPTS (ALWAYS LAST)
```

## Go Buildpack Implementation

In the Go buildpack, we implement this ordering using numbered `.opts` files:

### Directory Structure
```
$DEPS_DIR/0/
  java_opts/
    05_jre.opts                  # JRE base options (memory calculator, JVMKill, etc.)
    17_container_security.opts   # Container Security Provider (Line 51)
    20_debug.opts                # Debug framework (Line 54)
    29_jmx.opts                  # JMX framework (Line 63)
    31_jrebel.opts               # JRebel agent (Line 65)
    99_user_java_opts.opts       # User-defined JAVA_OPTS (Line 82, ALWAYS LAST)
```

### Assembly at Runtime

A single `profile.d/00_java_opts.sh` script reads all `.opts` files in order:

```bash
#!/bin/bash
export JAVA_OPTS=""
for opts_file in $DEPS_DIR/0/java_opts/*.opts; do
    if [ -f "$opts_file" ]; then
        JAVA_OPTS="$JAVA_OPTS $(cat $opts_file)"
    fi
done
export JAVA_OPTS
```

This ensures:
1. **Explicit ordering** via numbered filenames (shell glob sorts numerically)
2. **Container Security Provider runs BEFORE JRebel** (07 < 20)
3. **User JAVA_OPTS override everything** (99 runs last)

## Critical Ordering Dependencies

### Container Security Provider (Priority 17, Line 51)
- **Must run EARLY** because it modifies:
  - `-Xbootclasspath/a:` (prepends JAR to bootstrap classpath)
  - `-Djava.security.properties=` (overrides security configuration)
- These settings affect JVM initialization and security subsystem

### JRebel Agent (Priority 31, Line 65)
- **Must run AFTER Container Security Provider** because:
  - JRebel is a native agent (`-agentpath:`)
  - Requires access to JVM internals that may be restricted by security providers
  - If security settings change AFTER JRebel loads, JRebel crashes with:
    ```
    JRebel-JVMTI [FATAL] A fatal error occurred while processing the base Java classes
    Caused by: java.security.NoSuchAlgorithmException: SHA MessageDigest not available
    ```

### JavaOpts (Priority 99)
- **Must run LAST** to allow users to override any framework-contributed JAVA_OPTS
- Example: User sets `-Xmx2g` to override memory calculator's `-Xmx768M`

## Adding New Frameworks

When implementing a new framework that contributes JAVA_OPTS:

1. **Determine priority** based on Ruby buildpack ordering (see table above)
2. **Write `.opts` file** with appropriate priority prefix:
   ```go
   optsContent := fmt.Sprintf("-javaagent:%s", agentPath)
   optsFile := fmt.Sprintf("%02d_%s.opts", priority, frameworkName)
   f.context.Stager.WriteFile(filepath.Join("java_opts", optsFile), optsContent)
   ```
3. **Update this document** with the new framework's priority

## Why Not Use Profile.d Script Per Framework?

**Problem**: Profile.d scripts execute sequentially at runtime in **alphabetical order**. This creates timing issues:
- `01_jrebel.sh` runs, sets `-agentpath:`
- `container_security_provider.sh` runs, appends `-Xbootclasspath/a:`
- JVM sees options in this order, but CSP needs to initialize BEFORE JRebel

**Solution**: Collect all options BEFORE JVM starts, assemble in correct priority order, then export as single `JAVA_OPTS` variable.

## References

- Ruby buildpack: `/home/ramonskie/workspace/tmp/orig-java/config/components.yml` lines 40-83
- Go buildpack framework registry: `src/java/frameworks/framework.go` lines 54-113
