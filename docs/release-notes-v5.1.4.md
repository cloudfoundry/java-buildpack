# v5.1.4 Release Notes

Covers `v5.1.3..v5.1.4`.

## Highlights

- **OpenJDK (BellSoft Liberica) JREs updated to releases that contain the fix for
  CVE-2026-114938 (Java4Shell).** `17.0.21.0.3+5` → `17.0.21.1+5`, `21.0.13.0.3+5` →
  `21.0.13.1+5` and `25.0.5.0.3+5` → `25.0.5.1+5` are the November releases with the
  fix for the Base64 decoder flaw (see the `v5.1.3` notes). With these JREs the
  `-XX:-UseBASE64Intrinsics` mitigation of `v5.1.3` is no longer added, and the
  staging warning no longer appears. The mitigation code itself is still in this
  release; it only applies to a JRE older than the fixed releases, for example one
  that is pinned or added by hand, and it is removed again in the next release
  ([#1567](https://github.com/cloudfoundry/java-buildpack/pull/1567)). The Zulu and
  SapMachine JREs already contained the fix in `v5.1.3`.
- **Regular OpenJDK updates for Java 8 and 11.** `8.0.513+9` → `8.0.514+5` and
  `11.0.33.0.3+7` → `11.0.33.1+5`.

## Dependency updates

JRE (net change over `v5.1.3`):

| JRE | Version lines |
|-----|---------------|
| OpenJDK (BellSoft Liberica) | 8: `8.0.513+9` → `8.0.514+5`; 11: `11.0.33.0.3+7` → `11.0.33.1+5`; 17: `17.0.21.0.3+5` → `17.0.21.1+5`; 21: `21.0.13.0.3+5` → `21.0.13.1+5`; 25: `25.0.5.0.3+5` → `25.0.5.1+5` |

Frameworks and containers:

| Dependency | Change |
|------------|--------|
| contrast-security | `6.36.0` → `6.37.0` |
| datadog-javaagent | `1.68.2` → `1.69.0` |
| tomcat | `10.1.61` → `10.1.62` (11 stays at `11.0.29`, 9 at `9.0.124`) |

## Known issues

- The New Relic agent is installed but never attached to the JVM (since `v5.0.4`).
  The fix is in the dependency pipeline, not in this buildpack
  ([#1542](https://github.com/cloudfoundry/java-buildpack/issues/1542),
  cloudfoundry/buildpacks-ci#714).
