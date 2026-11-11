# Integration test fixtures

Fixtures deployed by the integration tests in `src/integration`.

## Structural stubs

Minimal directory layouts used to exercise container and framework detection. Detection looks at file names and layout, not at what is inside a jar.

- `containers/groovy_*`, `play_*`, `ratpack_*`, `tomcat*`, `no_container_*`, `main`, `thin_jar_*`
- `frameworks/*`

The jars in `frameworks/auto_reconfiguration_servlet_3` and `frameworks/java_cf_boot_3` (`spring-boot-3.0.0.jar`, `spring-core-3.2.3.RELEASE.jar`) are 324 byte, manifest-only stubs: the Spring detection matches their file names (for example `spring-boot-3.*.jar`). Do not add real library jars there. The tests `Spring Auto-reconfiguration` and `Java CF Env` in `frameworks_test.go` fail when such a name no longer matches.

## Small hand-made apps

A few KB each, with `.java` sources and compiled classes (some with a fake `spring-boot-1.0.0.RELEASE.jar`). They are not real Spring Boot apps:

- `containers/spring_boot_staged`, `containers/spring_boot_multi_framework`, `apps/integration_valid`
- `containers/dist_zip`, `containers/dist_zip_app_classpath`
- `containers/no_container_maven_source`, `no_container_gradle_source`, `no_container_gradle_kotlin_source`

## Downloaded fixtures

Real Spring Boot jars are downloaded from a [java-test-applications](https://github.com/cloudfoundry/java-test-applications) release at test start (not in cached mode). The version is pinned in `fixtures_helper_test.go`.
