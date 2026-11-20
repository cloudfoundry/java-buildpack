# Integration test fixtures

Fixtures deployed by the integration tests in `src/integration`.

## Real apps (downloaded)

Spring Boot 3 and 4.1 apps, and executable WAR/JAR archives, are downloaded from a
[cloudfoundry/java-test-applications](https://github.com/cloudfoundry/java-test-applications) release at test start (not in cached mode).
The version is pinned in `fixtures_helper_test.go`. Set `JAVA_TEST_APPS_BASE_URL` to use a not-yet-released build.

Tests use the Spring Boot 4.1 app on `defaultJavaVersion` (Java 25) unless the test is about a specific Java or Spring Boot version.
Java 8 and 11 are covered by the Tomcat, DistZip and JavaMain suites, as no supported Spring Boot runs there.

## Structural stubs

Minimal directory layouts used to exercise container and framework detection. They are matched by file name or layout, never by jar contents.
Some of them depend on their contents: for example `main` and `thin_jar_*` need their `META-INF/MANIFEST.MF` (the Java Main container reads `Main-Class` from it), so do not drop manifests when simplifying a fixture.

- `containers/groovy_*`, `play_*`, `ratpack_*`, `tomcat*`, `main`, `thin_jar_*`
- `containers/no_container_*`: negative cases that the tests expect to be rejected (for example source-only Maven and Gradle directories with no compiled artifact, `container_detection_test.go`). Do not compile them.
- `frameworks/*`

Only the Spring dependency stubs are matched by file name alone: the jars in `frameworks/auto_reconfiguration_servlet_3` (`spring-boot-3.0.0.jar`, `spring-core-3.2.3.RELEASE.jar`) are 324 byte, manifest-only stubs and the Spring detection looks at their names (for example `spring-boot-3.*.jar`). Do not add real library jars there. The test `Spring Auto-reconfiguration` in `frameworks_test.go` fails when such a name no longer matches.

## Small hand-made apps

A few KB each, with compiled classes and sources:

- `containers/dist_zip`, `containers/dist_zip_app_classpath`
