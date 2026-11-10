# v5.1.2 Release Notes

Covers `v5.1.1..v5.1.2`.

## Highlights

- **Spring Boot executable WAR detection fixed.** Apps packaged as executable WARs
  (`java -jar myapp.war`) were mistakenly claimed by the Tomcat container, which
  deployed them as plain servlet applications and never invoked `WarLauncher`.
  `SpringBootContainer` now recognises executable WARs by their manifest markers
  (`WarLauncher` `Main-Class`, or both `Start-Class` and `Spring-Boot-Version`), and
  the Tomcat container steps aside when a `Main-Class` is present in
  `META-INF/MANIFEST.MF` — restoring parity with the Ruby v4 buildpack
  ([#1533](https://github.com/cloudfoundry/java-buildpack/pull/1533)).
- **AspectJ weaver picks up `aop.xml` inside Spring Boot JARs.** The AspectJ
  framework now also looks for `aop.xml` under `BOOT-INF/classes/META-INF/`, which
  is where Spring Boot stores it when the app is packaged as an executable JAR
  ([#1535](https://github.com/cloudfoundry/java-buildpack/pull/1535)).
- **`detect` no longer claims Maven/Gradle source trees.** Pushing a source directory
  (containing only `pom.xml` or `build.gradle` but no compiled artifact) previously
  caused the buildpack to claim the app and then fail in the container phase. The
  detect script now only claims projects with a runnable artifact
  ([#1522](https://github.com/cloudfoundry/java-buildpack/pull/1522)).
- **Container security provider updated to 1.22.0.** The provider now keeps the
  current key pair when a key and certificate mismatch, instead of replacing it
  with an invalid pair. It also logs trust store certificate counts and a blocklist
  summary once per JVM, and repeated system trust/key manager messages are
  now logged at `FINE` instead of `INFO`
  ([release notes](https://github.com/cloudfoundry/java-buildpack-security-provider/releases/tag/v1.22.0)).

## Bug fixes

- Detect Spring Boot executable WAR before Tomcat claims it; restore Tomcat
  `Main-Class` guard from Ruby v4 (#1533, thanks @ivzhelev).
- Fix manifest continuation-line unfolding in `getWarLauncherClass` /
  `getLauncherClass` via `parseMainClass` (#1533).
- Fix Spring Boot 3.0/3.1 loader package threshold detection (#1533).
- Fix `detect` to not claim Maven/Gradle source-only directories (#1522).
- Fix detection of AspectJ `aop.xml` in Spring Boot `BOOT-INF/classes/META-INF/`
  (#1535).
- Fix Google Stackdriver Profiler agent SHA256 (#1519).
- Container security provider: keep current key pair on key/certificate mismatch
  (security-provider #16).
- Container security provider: log system trust/key manager additions at `FINE`
  instead of `INFO` on every factory initialization (security-provider #17, #13).

## New features

- Zulu JRE is now excluded from the `minimal` and `standard` packaging profiles,
  reducing the default offline buildpack size
  ([#1531](https://github.com/cloudfoundry/java-buildpack/pull/1531)).

## Dependency updates

JRE (net change over `v5.1.1`; intermediate bumps omitted):

| JRE | Version lines |
|-----|---------------|
| OpenJDK (BellSoft Liberica) | 8: `8.0.513+7` → `8.0.513+9`; 11: `11.0.33.0.3+5` → `11.0.33.0.3+7` |
| Zulu | 17: `17.0.21` → `17.0.21.0.3` |

Frameworks, containers and drivers:

| Dependency | Change |
|------------|--------|
| open-telemetry-javaagent | `2.32.0` → `2.33.1` |
| splunk-otel-javaagent | `2.32.0` → `2.33.1` |
| datadog-javaagent | `1.67.1` → `1.68.1` |
| sealights-agent | `4.0.2836` → `4.0.2842` |
| jrebel | `2026.4.0` → `2026.4.1` |
| contrast-security | `6.35.3` → `6.36.0` |
| container-security-provider | `1.21.1` → `1.22.0` |
| jacoco | `0.8.15` → `0.8.16` |

## Documentation and tests

- Added `docs/spring-boot-executable-war.md` explaining the detection fix and
  the pre-fix workaround (#1533).
- Scoped the Spring Boot executable WAR breaking-change note to apply only to
  versions before v5.1.2 (#1533).
- Integration test infrastructure: retry only failed tests rather than the whole
  suite, back off between retries, and run Docker (Switchblade) tests in parallel
  by default (#1523, #1526, #1530).

## Known issues

- Apps launched through their own bundled start script (Play with `bin/<name>`, and
  possibly `dist_zip`, staged Spring Boot, Tomcat and Groovy) split `JAVA_OPTS` on
  whitespace, because those scripts expand it unquoted. A multi-word value, such as a
  quoted cron expression, can cause `Could not find or load main class`. Use
  space-free `JAVA_OPTS` values for these apps
  ([#1441](https://github.com/cloudfoundry/java-buildpack/issues/1441)).
