# v5.1.1 Release Notes

Covers `v5.1.0..v5.1.1`.

## Highlights

- **JEP 322 JRE version support.** JRE versions with more than four fields, as used by
  the new Oracle-aligned quarterly scheme (e.g. `21.0.13.0.3+5`), are now parsed and
  selected correctly ([#1462](https://github.com/cloudfoundry/java-buildpack/pull/1462),
  [#1460](https://github.com/cloudfoundry/java-buildpack/pull/1460) for 4-digit
  SapMachine versions). The bundled `libbuildpack` was bumped accordingly.
- **New framework: Elastic OTel Java agent** (`elastic-otel-javaagent` 1.14.0)
  ([#1360](https://github.com/cloudfoundry/java-buildpack/pull/1360), thanks @jackshirazi).
- **Latest JDK security updates** for all supported JRE vendors (see below).

## New features

- Add Elastic OTel Java agent framework (#1360).

## Bug fixes

- Restore export of `MALLOC_ARENA_MAX` in the start command (regression, #1434, thanks @efreudenreich).
- Preserve user `JAVA_OPTS` in the `dist_zip`/Play `profile.d` scripts (#1435, fixes #1432).
- Only detect `otel-collector` service names for OpenTelemetry, as documented, instead of
  any service name containing "otel" (#1471).
- Fix framework jar globs so they match jar names produced by the dependency pipeline (#1455).
- Remove dead `memory_calculator.sh` script generation (#1436).

## Dependency updates

JRE (net change over `v5.1.0`; intermediate bumps omitted):

| JRE | Version lines |
|-----|---------------|
| OpenJDK (BellSoft Liberica) | 8: `8.0.504+1` → `8.0.513+7`; 11: `11.0.32+11` → `11.0.33.0.3+5`; 17: `17.0.20+10` → `17.0.21.0.3+5`; 21: `21.0.12+10` → `21.0.13.0.3+5`; 25: `25.0.4+9` → `25.0.5.0.3+5` |
| SapMachine | 17: `17.0.20.1` → `17.0.21.0.3`; 21: `21.0.12.1` → `21.0.13.0.3`; 25: `25.0.4.1` → `25.0.5.0.3` |
| Zulu | 8: `8.0.504` → `8.0.512`; 11: `11.0.32` → `11.0.33`; 17: `17.0.20` → `17.0.21` |

Frameworks, containers and drivers:

| Dependency | Change |
|------------|--------|
| elastic-otel-javaagent | new, `1.14.0` |
| open-telemetry-javaagent | `2.31.1` → `2.32.0` |
| splunk-otel-javaagent | `2.31.1` → `2.32.0` |
| datadog-javaagent | `1.66.0` → `1.67.1` |
| elastic-apm-agent | `1.57.0` → `1.57.1` |
| contrast-security | `6.35.1` → `6.35.3` |
| sealights-agent | `4.0.2830` → `4.0.2836` |
| jrebel | `2026.3.2` → `2026.4.0` |
| container-security-provider | `1.20.0` → `1.21.1` |
| tomcat | 9: `9.0.122` → `9.0.123`; 10.1: `10.1.60` → `10.1.61`; 11: `11.0.26` → `11.0.27` |
| postgresql-jdbc | `42.7.13` → `42.7.14` |
| mariadb-jdbc | `3.5.10` → `3.5.11` |
| golang.org/x/net (build) | `0.53.0` → `0.55.0` |

OpenJDK deprecation dates were adjusted (#1457, thanks @kiril-keranov).

## Documentation and tests

- Updated memory calculator and debugging docs for v5 (#1447).
- Skip integration cleanup for skipped tests (#1454); Play `#1301` regression test now
  uses a space-free `JAVA_OPTS` value (#1442).

## Known issues

- Apps launched through their own bundled start script (Play with `bin/<name>`, and
  possibly `dist_zip`, staged Spring Boot, Tomcat and Groovy) split `JAVA_OPTS` on
  whitespace, because those scripts expand it unquoted. A multi-word value, such as a
  quoted cron expression, can cause `Could not find or load main class`. Use
  space-free `JAVA_OPTS` values for these apps
  ([#1441](https://github.com/cloudfoundry/java-buildpack/issues/1441)).
