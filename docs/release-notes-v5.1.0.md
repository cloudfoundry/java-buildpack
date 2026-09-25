# v5.1.0 Release Notes

## 🎉 First GA Release

**v5.1.0 is the first generally available (GA) release of the Go-based Java Buildpack.**

Per [RFC-0050][] (Java Buildpack Migration to Golang), the `v5.0.x` series was an
experimental release intended to collect broad community feedback before committing to
API/behavior stability. No unannounced breaking changes were introduced since `v5.0.0` —
see "Notable fixes since v5.0.0" below for behavior changes that shipped as bug fixes.

v5.1.0 supersedes the experimental `5.0.x` releases. The Ruby-based buildpack (`4.x`) is
no longer receiving feature updates; operators are encouraged to migrate to `v5.1.0` or
later. See the [Migration Guide](../adoption-migration-details.md) for upgrade guidance,
and [`RUBY_VS_GO_BUILDPACK_COMPARISON.md`](../RUBY_VS_GO_BUILDPACK_COMPARISON.md) for a
detailed Ruby vs. Go feature comparison.

[RFC-0050]: https://github.com/cloudfoundry/community/blob/main/toc/rfc/rfc-0050-java-buildpack-migration-to-golang.md

## Notable fixes since v5.0.0

`git log v5.0.0..v5.1.0` introduced no intentionally-breaking API/config changes (no
removed frameworks, no default-value flips beyond what `v5.0.0` already announced).
However, several bug fixes changed previously-buggy or inconsistent runtime behavior.
These are fixes "for the better" (bringing behavior in line with intent), but some
upgrading apps could still observe a difference:

- Fixed `JBP_CONFIG_JAVA_MAIN` not taking effect when the app is detected as Spring Boot
  — silently-ignored config now applies.
- Fixed `SERVER_PORT`/`$PORT` injection for the Spring Boot JAR, Spring Boot CLI, and
  generic `profile.d` scripts (previously not shell-expanded correctly).
- Fixed `LoadConfig` reading the wrong `JBP_CONFIG_*_JRE` vendor prefix — configs could
  previously silently apply to the wrong JRE vendor.
- Restricted `-XX:ActiveProcessorCount` to HotSpot JREs only (previously applied
  incorrectly to non-HotSpot JREs like IBM/OpenJ9).
- Changed Tomcat's `server.xml` to set `allowSchemeMismatch=true`.
- Fixed multiple Tomcat context-path/`ROOT.xml`/WAR-filename XML-escaping issues —
  changes the generated Tomcat context descriptors for non-root context paths.
- Fixed multiple `JAVA_OPTS`/`USER_JAVA_OPTS` assembly-script quoting/escaping issues
  (multiline values, `$DEPS_DIR`/`$HOME` substitution, bash 5.1 compatibility).
- Clarified/fixed Java-version-detection fallback-to-default behavior.

## 💬 Feedback Welcome

Try it out and report any issues or unexpected behaviour:
- 🐛 [Open an issue](https://github.com/cloudfoundry/java-buildpack/issues)
- 💬 [#buildpacks on CF Slack](https://cloudfoundry.slack.com/archives/C02HWMDUQ)
- 📖 [Migration Guide](../adoption-migration-details.md)
