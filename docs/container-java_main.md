# Java Main Container
The Java Main Container allows an application that provides a class with a `main()` method to be run.  The application is executed with a command of the form:

```bash
<JAVA_HOME>/bin/java -cp . com.gopivotal.SampleClass
```

Command line arguments may optionally be configured.

<table>
  <tr>
    <td><strong>Detection Criteria</strong></td>
    <td><tt>Main-Class</tt> attribute set in <tt>META-INF/MANIFEST.MF</tt>, or <tt>java_main_class</tt> set in <tt>JBP_CONFIG_JAVA_MAIN</tt></td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>java-main</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

If the application uses Spring, [Spring profiles][] can be specified by setting the [`SPRING_PROFILES_ACTIVE`][] environment variable. This is automatically detected and used by Spring. The [Java CfEnv](framework-java-cfenv.md) framework — the replacement for the deprecated Spring Auto-reconfiguration — activates the `cloud` profile at runtime; you can also add it explicitly with `SPRING_PROFILES_INCLUDE=cloud`.

## Spring Boot

If `java_main_class` is set to one of Spring Boot's launchers (`JarLauncher`, `PropertiesLauncher` or `WarLauncher`), the Java Main Container sets `SERVER_PORT=$PORT` so that the application binds to the CF-assigned port.

## CF Tasks

The buildpack emits both `web` and `task` process types with the same command so `cf run-task` works without `--command`.

To run a task with a different main class (batch job, migration, etc.), set `java_main_class` to Spring Boot's `PropertiesLauncher` at staging time:

```yaml
env:
  JBP_CONFIG_JAVA_MAIN: '{java_main_class: "org.springframework.boot.loader.launch.PropertiesLauncher"}'
```

Then override the main class per task at run time (requires CF CLI v7+):

```bash
cf run-task my-app --env JAVA_OPTS="-Dloader.main=com.example.BatchJob"
```

`-Dloader.main` is a Spring Boot `PropertiesLauncher` system property -- the buildpack passes it through to the JVM unchanged. `JBP_CONFIG_JAVA_MAIN` is a staging-time setting that applies to both `web` and `task`; `-Dloader.main` is a per-task runtime override.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The container can be configured using the `JBP_CONFIG_JAVA_MAIN` environment variable.

| Name | Description
| ---- | -----------
| `arguments` | Optional command line arguments to be passed to the Java main class. The arguments are specified as a single YAML scalar in plain style or enclosed in single or double quotes.
| `java_main_class` | Optional Java class name to run. Values containing whitespace are rejected with an error, but all others values appear without modification on the Java command line. If not specified, the Java Manifest value of `Main-Class` is used. Setting this overrides container detection — even Spring Boot apps will use the Java Main container when this is set.

### Example: PropertiesLauncher with external config

```yaml
env:
  JBP_CONFIG_JAVA_MAIN: '{java_main_class: "org.springframework.boot.loader.launch.PropertiesLauncher", arguments: "--loader.home=/home/vcap/data"}'
  JAVA_OPTS: '-Dloader.path=/home/vcap/data/lib'
```

[Configuration and Extension]: ../README.md#configuration-and-extension
[Spring profiles]:http://blog.springsource.com/2011/02/14/spring-3-1-m1-introducing-profile/
[`SPRING_PROFILES_ACTIVE`]: http://static.springsource.org/spring/docs/3.1.x/javadoc-api/org/springframework/core/env/AbstractEnvironment.html#ACTIVE_PROFILES_PROPERTY_NAME
