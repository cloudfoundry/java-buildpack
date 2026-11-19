# Integration test fixtures

Fixtures deployed by the integration tests in `src/integration`.

## Structural stubs

Minimal directory layouts used to exercise container and framework detection. Some of them depend on their contents: for example `main` and `thin_jar_*` need their `META-INF/MANIFEST.MF` (the Java Main container reads `Main-Class` from it), so do not drop manifests when simplifying a fixture.

- `containers/groovy_*`, `play_*`, `ratpack_*`, `tomcat*`, `main`, `thin_jar_*`
- `containers/no_container_*`: negative cases that the tests expect to be rejected (for example source-only Maven and Gradle directories with no compiled artifact, `container_detection_test.go`). Do not compile them.
- `frameworks/*`

Only the Spring dependency stubs are matched by file name alone: the jars in `frameworks/auto_reconfiguration_servlet_3` and `frameworks/java_cf_boot_3` (`spring-boot-3.0.0.jar`, `spring-core-3.2.3.RELEASE.jar`) are 324 byte, manifest-only stubs and the Spring detection looks at their names (for example `spring-boot-3.*.jar`). Do not add real library jars there. The tests `Spring Auto-reconfiguration` and `Java CF Env` in `frameworks_test.go` fail when such a name no longer matches.

## Small hand-made apps

A few KB each, with compiled classes (some with `.java` sources and a fake `spring-boot-1.0.0.RELEASE.jar`). They are not real Spring Boot apps:

- `containers/spring_boot_staged`, `containers/spring_boot_multi_framework`, `apps/integration_valid`
- `containers/dist_zip`, `containers/dist_zip_app_classpath`

## Downloaded fixtures

Real Spring Boot jars are downloaded from a [java-test-applications](https://github.com/cloudfoundry/java-test-applications) release at test start (not in cached mode). The version is pinned in `fixtures_helper_test.go`.
