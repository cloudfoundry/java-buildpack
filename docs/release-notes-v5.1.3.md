# v5.1.3 Release Notes

Covers `v5.1.2..v5.1.3`.

## Highlights

- **Mitigation for the OpenJDK Base64 decoder flaw (CVE-2026-114938).** According to
  the published analyses, Java 17.0.6 and later, on x86-64 CPUs with AVX-512 VBMI,
  can overflow a heap array in the Base64 decoder. The OpenJDK (BellSoft Liberica)
  JRE in this release is still `17.0.21.0.3+5`, `21.0.13.0.3+5` and `25.0.5.0.3+5`,
  which are affected. Fixed Liberica releases (`17.0.21.1`, `21.0.13.1`, `25.0.5.1`)
  are published but are not in this release yet. Until then the buildpack adds
  `-XX:-UseBASE64Intrinsics` to `JAVA_OPTS`, and to `JDK_JAVA_OPTIONS` so that
  `java` processes that do not use `$JAVA_OPTS` (custom start commands, tasks) are
  covered too. The option is not added for JREs that contain the fix, for Java 8 and
  11 (not affected), or for Zulu and SapMachine, whose releases in this buildpack
  already contain the fix. A warning is logged during staging when the option is
  added ([#1561](https://github.com/cloudfoundry/java-buildpack/pull/1561)).
- **SapMachine 17, 21 and 25 updated to releases that contain the fix.** SapMachine
  `17.0.21.0.3` → `17.0.21.1`, `21.0.13.0.3` → `21.0.13.1` and `25.0.5.0.3` →
  `25.0.5.1` are the November releases with the fix for CVE-2026-114938, so apps
  that select SapMachine (`JBP_CONFIG_SAP_MACHINE_JRE`) do not need the mitigation
  ([#1556](https://github.com/cloudfoundry/java-buildpack/pull/1556),
  [#1555](https://github.com/cloudfoundry/java-buildpack/pull/1555),
  [#1560](https://github.com/cloudfoundry/java-buildpack/pull/1560)).

## New features

- New opt-outs for the mitigation, set in `JBP_CONFIG_OPEN_JDK_JRE` (or
  `JBP_CONFIG_OPENJDK`): `{base64_intrinsics_mitigation: {enabled: false}}` turns it
  off completely, `{base64_intrinsics_mitigation: {jdk_java_options: false}}` keeps
  only the `JAVA_OPTS` part
  ([#1561](https://github.com/cloudfoundry/java-buildpack/pull/1561)). The setting
  is read during staging, so restage the app after changing it.
- A `java` started by hand in a plain `cf ssh` session does not get the option,
  because such a session does not run the `profile.d` scripts. The JVM of the app,
  tasks and custom start commands do get it.

## Dependency updates

JRE (net change over `v5.1.2`):

| JRE | Version lines |
|-----|---------------|
| Zulu | 8: `8.0.512` → `8.0.514`; 11: `11.0.33` → `11.0.33.1`; 17: `17.0.21.0.3` → `17.0.21.1` |
| SapMachine | 17: `17.0.21.0.3` → `17.0.21.1`; 21: `21.0.13.0.3` → `21.0.13.1`; 25: `25.0.5.0.3` → `25.0.5.1` |

Frameworks and containers:

| Dependency | Change |
|------------|--------|
| datadog-javaagent | `1.68.1` → `1.68.2` |
| sealights-agent | `4.0.2842` → `4.0.2844` |
| jprofiler-profiler | `16.2.1` → `16.3.1` |
| tomcat | `11.0.27` → `11.0.29`, `9.0.123` → `9.0.124` (10.1 stays at `10.1.61`) |

Go module `go.opentelemetry.io/otel` `1.36.0` → `1.41.0`
([#1528](https://github.com/cloudfoundry/java-buildpack/pull/1528)).

## Documentation and tests

- The JRE documentation of OpenJDK describes the mitigation and its opt-outs
  ([#1561](https://github.com/cloudfoundry/java-buildpack/pull/1561)).
- Added integration tests for Spring Boot executable WAR detection
  ([#1543](https://github.com/cloudfoundry/java-buildpack/pull/1543)).
- Removed the skipped Play `JAVA_OPTS` integration test
  ([#1540](https://github.com/cloudfoundry/java-buildpack/pull/1540)).
- Added the release notes of `v5.1.2` to the repository
  ([#1538](https://github.com/cloudfoundry/java-buildpack/pull/1538)).

## Known issues

- The New Relic agent is installed but never attached to the JVM (since `v5.0.4`).
  The fix is in the dependency pipeline, not in this buildpack
  ([#1542](https://github.com/cloudfoundry/java-buildpack/issues/1542),
  cloudfoundry/buildpacks-ci#714).
