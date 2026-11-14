# Integration test fixtures

Fixtures deployed by the integration tests in `src/integration`.

## Real apps (downloaded)

Spring Boot 3 and 4.1 apps, and executable WAR/JAR archives, are downloaded from a
[cloudfoundry/java-test-applications](https://github.com/cloudfoundry/java-test-applications) release at test start.
The version is pinned in `fixtures_helper_test.go`. Set `JAVA_TEST_APPS_BASE_URL` to use a not-yet-released build.

Tests use the Spring Boot 4.1 app on `defaultJavaVersion` (Java 25) unless the test is about a specific Java or Spring Boot version.
Java 8 and 11 are covered by the Tomcat, DistZip and JavaMain suites, as no supported Spring Boot runs there.

## Structural stubs

Minimal directory layouts used to exercise container and framework detection. They are matched by file name or layout, never by jar contents.

- `containers/*`
- `frameworks/*`

The `spring-boot-*.jar` and `spring-core-*.jar` files are empty, manifest-only jars. Detection only looks at the file name, so do not add real library jars.

## Small apps with sources

- `containers/dist_zip`
- `containers/no_container_maven_source`, `no_container_gradle_source`, `no_container_gradle_kotlin_source`
