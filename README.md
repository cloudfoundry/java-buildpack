# Cloud Foundry Java Buildpack

The `java-buildpack` is a [Cloud Foundry][] buildpack for running JVM-based applications. It is designed to run many JVM-based applications ([Grails][], [Groovy][], Java Main, [Play Framework][], [Spring Boot][], and Servlet) with no additional configuration, but supports configuration of the standard components, and extension to add custom components.

## Usage
To use this buildpack specify the URI of the repository when pushing an application to Cloud Foundry:

```bash
$ cf push <APP-NAME> -p <ARTIFACT> -b https://github.com/cloudfoundry/java-buildpack.git
```

## Examples
The following are _very_ simple examples for deploying the artifact types that we support.

* [Embedded web server](docs/example-embedded-web-server.md)
* [Grails](docs/example-grails.md)
* [Groovy](docs/example-groovy.md)
* [Java Main](docs/example-java_main.md)
* [Play Framework](docs/example-play_framework.md)
* [Servlet](docs/example-servlet.md)
* [Spring Boot CLI](docs/example-spring_boot_cli.md)

## Configuration and Extension

The buildpack default configuration can be overridden with an environment variable matching the configuration file you wish to override minus the `.yml` extension. It is not possible to add new configuration properties and properties with `nil` or empty values will be ignored by the buildpack (in this case you will have to extend the buildpack, see below). The value of the variable should be valid inline yaml, referred to as "flow style" in the yaml spec ([Wikipedia][] has a good description of this yaml syntax).

There are two levels of overrides: operator and application developer.

  - If you are an operator that wishes to override configuration across a foundation, you may do this by setting environment variable group entries that begin with a prefix of `JBP_DEFAULT`.
  - If you are an application developer that wishes to override configuration for an individual application, you may do this by setting environment variables that begin with a prefix of `JBP_CONFIG`. 

Here are some examples:

### Operator

1. To change the default version of Java to 11 across all applications on a foundation.

```bash
$ cf set-staging-environment-variable-group '{"JBP_DEFAULT_OPEN_JDK_JRE":"{jre: {version: 11.+ }}"}'
```

2. To change the default repository root across all applications on a foundation. Be careful to ensure that your JSON is properly escaped.

```bash
$ cf set-staging-environment-variable-group '{"JBP_DEFAULT_REPOSITORY": "{default_repository_root: \"http://repo.example.io\" }"}'
```

3. To change the default JVM vendor across all applications on a foundation. Be careful to ensure that your JSON is properly escaped.

```bash
$ cf set-staging-environment-variable-group '{"JBP_DEFAULT_COMPONENTS": "{jres: [\"JavaBuildpack::Jre::ZuluJRE\"]}"}'
```

### Application Developer

1. To change the default version of Java to 11 and adjust the memory heuristics then apply this environment variable to the application.

```bash
$ cf set-env my-application JBP_CONFIG_OPEN_JDK_JRE '{ jre: { version: 11.+ }, memory_calculator: { stack_threads: 25 } }'
```

2. If the key or value contains a special character such as `:` it should be escaped with double quotes. For example, to change the default repository path for the buildpack.

```bash
$ cf set-env my-application JBP_CONFIG_REPOSITORY '{ default_repository_root: "http://repo.example.io" }'
```

3. If the key or value contains an environment variable that you want to bind at runtime you need to escape it from your shell. For example, to add command line arguments containing an environment variable to a [Java Main](docs/container-java_main.md) application.

```bash
$ cf set-env my-application JBP_CONFIG_JAVA_MAIN '{ arguments: "--server.port=9090 --foo=bar" }'
```

4. An example of configuration is to specify a `javaagent` that is packaged within an application.

```bash
$ cf set-env my-application JAVA_OPTS '-javaagent:app/META-INF/myagent.jar -Dmyagent.config_file=app/META-INF/my_agent.conf'
```

5. Environment variable can also be specified in the applications `manifest` file. For example, to specify an environment variable in an applications manifest file that disables Auto-reconfiguration.

```bash
env:
  JBP_CONFIG_SPRING_AUTO_RECONFIGURATION: '{ enabled: false }'
```

6. This final example shows how to change the version of Tomcat that is used by the buildpack with an environment variable specified in the applications manifest file.

```bash
env:
  JBP_CONFIG_TOMCAT: '{ tomcat: { version: 8.0.+ } }'
```

See the [Environment Variables][] documentation for more information.

To learn how to configure various properties of the buildpack, follow the "Configuration" links below.

The buildpack supports extension through the use of Git repository forking. The easiest way to accomplish this is to use [GitHub's forking functionality][] to create a copy of this repository. Make the required extension changes in the copy of the repository. Then specify the URL of the new repository when pushing Cloud Foundry applications. If the modifications are generally applicable to the Cloud Foundry community, please submit a [pull request][] with the changes. More information on extending the buildpack is available [here](docs/extending.md).

## Ruby vs Go Migration Status

This Go-based buildpack is a migration from the original Ruby-based Cloud Foundry Java Buildpack. For comprehensive information about the migration status, component parity, and architectural differences:

* **[Ruby vs Go Buildpack Comparison](comparison.md)** - Comprehensive comparison of components, features, and production readiness assessment (92.9% component parity, production-ready for 98%+ of Java applications)
* **[Dependency Installation Comparison](ruby_vs_go_buildpack_comparison.md)** - Technical deep-dive into how dependency extraction differs between Ruby and Go implementations

**⚠️ Important Migration Note:** The Go buildpack does **NOT** support the Ruby buildpack's `repository_root` configuration approach for custom JREs (via `JBP_CONFIG_*` environment variables). Custom JREs now require forking the buildpack and modifying `manifest.yml`. See [Custom JRE Usage](docs/custom-jre-usage.md) for details.

**Quick Status Summary** (as of December 16, 2025):
- ✅ All 8 container types implemented (100%)
- ✅ All 7 JRE providers implemented (3 in manifest + 4 BYOL via custom manifest)
- ✅ 37 of 40 frameworks implemented (92.5%)
- ✅ All integration tests passing
- ⚠️ Only 3 missing frameworks are niche/deprecated (affecting <2% of applications)
- 📝 BYOL JREs (GraalVM, IBM, Oracle, Zing) require custom manifest - see [Custom JRE Usage](docs/custom-jre-usage.md)

For historical analysis documents from development sessions, see [`docs/archive/`](docs/archive/).

## Additional Documentation
* [Design](docs/design.md)
* [Security](docs/security.md)
* Standard Containers
  * [Dist ZIP](docs/container-dist_zip.md)
  * [Groovy](docs/container-groovy.md) ([Configuration](docs/container-groovy.md#configuration))
  * [Java Main](docs/container-java_main.md) ([Configuration](docs/container-java_main.md#configuration))
  * [Play Framework](docs/container-play_framework.md)
  * [Ratpack](docs/container-ratpack.md)
  * [Spring Boot](docs/container-spring_boot.md)
  * [Spring Boot CLI](docs/container-spring_boot_cli.md) ([Configuration](docs/container-spring_boot_cli.md#configuration))
  * [Tomcat](docs/container-tomcat.md) ([Configuration](docs/container-tomcat.md#configuration))
* Standard Frameworks
  * [AppDynamics Agent](docs/framework-app_dynamics_agent.md) ([Configuration](docs/framework-app_dynamics_agent.md#configuration))
  * [AspectJ Weaver Agent](docs/framework-aspectj_weaver_agent.md) ([Configuration](docs/framework-aspectj_weaver_agent.md#configuration))
  * [Azure Application Insights Agent](docs/framework-azure_application_insights_agent.md) ([Configuration](docs/framework-azure_application_insights_agent.md#configuration))
  * [Checkmarx IAST Agent](docs/framework-checkmarx_iast_agent.md) ([Configuration](docs/framework-checkmarx_iast_agent.md#configuration))
  * [Client Certificate Mapper](docs/framework-client_certificate_mapper.md) ([Configuration](docs/framework-client_certificate_mapper.md#configuration))
  * [Container Customizer](docs/framework-container_customizer.md) ([Configuration](docs/framework-container_customizer.md#configuration))
  * [Container Security Provider](docs/framework-container_security_provider.md) ([Configuration](docs/framework-container_security_provider.md#configuration))
  * [Contrast Security Agent](docs/framework-contrast_security_agent.md) ([Configuration](docs/framework-contrast_security_agent.md#configuration))
  * [DataDog](docs/framework-datadog_javaagent.md) ([Configuration](docs/framework-datadog_javaagent.md#configuration)
  * [Debug](docs/framework-debug.md) ([Configuration](docs/framework-debug.md#configuration))
  * [Elastic APM Agent](docs/framework-elastic_apm_agent.md) ([Configuration](docs/framework-elastic_apm_agent.md#configuration))
  * [Dynatrace SaaS/Managed OneAgent](docs/framework-dynatrace_one_agent.md) ([Configuration](docs/framework-dynatrace_one_agent.md#configuration))
  * [Google Stackdriver Profiler](docs/framework-google_stackdriver_profiler.md) ([Configuration](docs/framework-google_stackdriver_profiler.md#configuration))
  * [Introscope Agent](docs/framework-introscope_agent.md) ([Configuration](docs/framework-introscope_agent.md#configuration))
  * [JaCoCo Agent](docs/framework-jacoco_agent.md) ([Configuration](docs/framework-jacoco_agent.md#configuration))
  * [Java CfEnv](docs/framework-java-cfenv.md) ([Configuration](docs/framework-java-cfenv.md#configuration))
  * [Java Memory Assistant](docs/framework-java_memory_assistant.md) ([Configuration](docs/framework-java_memory_assistant.md#configuration))
  * [Java Options](docs/framework-java_opts.md) ([Configuration](docs/framework-java_opts.md#configuration))
  * [JProfiler Profiler](docs/framework-jprofiler_profiler.md) ([Configuration](docs/framework-jprofiler_profiler.md#configuration))
  * [JRebel Agent](docs/framework-jrebel_agent.md) ([Configuration](docs/framework-jrebel_agent.md#configuration))
  * [JMX](docs/framework-jmx.md) ([Configuration](docs/framework-jmx.md#configuration))
  * [Luna Security Provider](docs/framework-luna_security_provider.md) ([Configuration](docs/framework-luna_security_provider.md#configuration))
  * [MariaDB JDBC](docs/framework-maria_db_jdbc.md) ([Configuration](docs/framework-maria_db_jdbc.md#configuration)) (also supports MySQL)
  * [Multiple Buildpack](docs/framework-multi_buildpack.md)
  * [Metric Writer](docs/framework-metric_writer.md) ([Configuration](docs/framework-metric_writer.md#configuration))
  * [New Relic Agent](docs/framework-new_relic_agent.md) ([Configuration](docs/framework-new_relic_agent.md#configuration))
  * [PostgreSQL JDBC](docs/framework-postgresql_jdbc.md) ([Configuration](docs/framework-postgresql_jdbc.md#configuration))
  * [ProtectApp Security Provider](docs/framework-protect_app_security_provider.md) ([Configuration](docs/framework-protect_app_security_provider.md#configuration))
  * [Riverbed AppInternals Agent](docs/framework-riverbed_appinternals_agent.md) ([Configuration](docs/framework-riverbed_appinternals_agent.md#configuration))
  * [Sealights Agent](docs/framework-sealights_agent.md) ([Configuration](docs/framework-sealights_agent.md#configuration))
  * [Seeker Security Provider](docs/framework-seeker_security_provider.md) ([Configuration](docs/framework-seeker_security_provider.md#configuration))
  * [Splunk Observability Cloud](docs/framework-splunk_otel_java_agent.md) ([Configuration](docs/framework-splunk_otel_java_agent.md#user-provided-service))
  * [Spring Auto Reconfiguration](docs/framework-spring_auto_reconfiguration.md) ([Configuration](docs/framework-spring_auto_reconfiguration.md#configuration))
  * [Spring Insight](docs/framework-spring_insight.md)
  * [SkyWalking Agent](docs/framework-sky_walking_agent.md) ([Configuration](docs/framework-sky_walking_agent.md#configuration))
  * [Takipi Agent](docs/framework-takipi_agent.md) ([Configuration](docs/framework-takipi_agent.md#configuration))
  * [YourKit Profiler](docs/framework-your_kit_profiler.md) ([Configuration](docs/framework-your_kit_profiler.md#configuration))
* Standard JREs (Included in Manifest)
  * [OpenJDK](docs/jre-open_jdk_jre.md) ([Configuration](docs/jre-open_jdk_jre.md#configuration)) - Default
  * [Azul Zulu](docs/jre-zulu_jre.md) ([Configuration](docs/jre-zulu_jre.md#configuration))
  * [SapMachine](docs/jre-sap_machine_jre.md) ([Configuration](docs/jre-sap_machine_jre.md#configuration))
* BYOL JREs (Require Custom Manifest - see [Custom JRE Usage](docs/custom-jre-usage.md))
  * [Azul Platform Prime (Zing)](docs/jre-zing_jre.md) ([Configuration](docs/jre-zing_jre.md#configuration))
  * [GraalVM](docs/jre-graal_vm_jre.md) ([Configuration](docs/jre-graal_vm_jre.md#configuration))
  * [IBM Semeru](docs/jre-ibm_jre.md) ([Configuration](docs/jre-ibm_jre.md#configuration))
  * [Oracle](docs/jre-oracle_jre.md) ([Configuration](docs/jre-oracle_jre.md#configuration))
* [Extending](docs/extending.md)
  * [Application](docs/extending-application.md)
  * [Droplet](docs/extending-droplet.md)
  * [BaseComponent](docs/extending-base_component.md)
  * [VersionedDependencyComponent](docs/extending-versioned_dependency_component.md)
  * [ModularComponent](docs/extending-modular_component.md)
  * [Caches](docs/extending-caches.md) ([Configuration](docs/extending-caches.md#configuration))
  * [Logging](docs/extending-logging.md) ([Configuration](docs/extending-logging.md#configuration))
  * [Repositories](docs/extending-repositories.md) ([Configuration](docs/extending-repositories.md#configuration))
  * [Utilities](docs/extending-utilities.md)
* [Debugging the Buildpack](docs/debugging-the-buildpack.md)
* [Buildpack Modes](docs/buildpack-modes.md)
* Related Projects
  * [Java Buildpack Dependency Builder](https://github.com/cloudfoundry/java-buildpack-dependency-builder)
  * [Java Buildpack Memory Calculator](https://github.com/cloudfoundry/java-buildpack-memory-calculator)
  * [Java Test Applications](https://github.com/cloudfoundry/java-test-applications)
  * [Java Buildpack System Tests](https://github.com/cloudfoundry/java-buildpack-system-test)
  * [jvmkill](https://github.com/cloudfoundry/jvmkill)

## Building Packages
The buildpack can be packaged up so that it can be uploaded to Cloud Foundry using the `cf create-buildpack` and `cf update-buildpack` commands. The Go buildpack uses the `buildpack-packager` tool to create packages.

**Requirements:**
- Go 1.21 or higher
- Git

Note that this process is not currently supported on Windows. It is possible it will work, but it is not tested.

### Online Package
The online package is a version of the buildpack that is as minimal as possible and is configured to connect to the network for all dependencies. This package is about 1-2 MB in size. To create the online package, run:

```bash
$ ./scripts/package.sh
...
Building buildpack (version: 0.0.0, stack: cflinuxfs4, cached: false, output: build/buildpack.zip)
```

### Offline Package
The offline package is a version of the buildpack designed to run without access to a network. It packages all dependencies listed in `manifest.yml` and includes them in the buildpack archive. To create the offline package, use the `--cached` flag:

```bash
$ ./scripts/package.sh --cached
...
Building buildpack (version: 0.0.0, stack: cflinuxfs4, cached: true, output: build/buildpack.zip)
```

The offline package will be significantly larger (1.0-1.2 GB depending on cached dependencies) as it includes all JRE versions and framework agents specified in `manifest.yml`.

### Package Versioning
To specify a version number when creating a package, use the `--version` flag:

```bash
$ ./scripts/package.sh --version 5.0.0
...
Building buildpack (version: 5.0.0, stack: cflinuxfs4, cached: false, output: build/buildpack.zip)
```

If no version is specified, the version from the `VERSION` file will be used (or `0.0.0` if the file doesn't exist).

### Package Options

The packaging script supports the following options:

```bash
$ ./scripts/package.sh --help

package.sh --version <version> [OPTIONS]
Packages the buildpack into a .zip file.

OPTIONS
  --help               -h            prints the command usage
  --version <version>  -v <version>  specifies the version number to use when packaging the buildpack
  --cached                           cache the buildpack dependencies (default: false)
  --stack  <stack>                   specifies the stack (default: cflinuxfs4)
  --output <file>                    output file path (default: build/buildpack.zip)
```

### Customizing Dependencies

To customize which dependencies are included in the buildpack, edit `manifest.yml`:

1. **Add/remove dependencies**: Modify the `dependencies` section
2. **Specify versions**: Use exact versions or version wildcards (e.g., `17.x` for latest Java 17)
3. **Add custom JREs**: For BYOL JREs (Oracle, GraalVM, IBM, Zing), add entries with your repository URIs (see [Custom JRE Usage](docs/custom-jre-usage.md))

Example manifest entry:
```yaml
dependencies:
  - name: openjdk
    version: 17.0.13
    uri: https://github.com/adoptium/temurin17-binaries/releases/download/...
    sha256: abc123...
    cf_stacks:
      - cflinuxfs4
```

**Note**: The Go buildpack does not use Ruby's `config/*.yml` files, `bundle`, or `rake` tasks. All dependency configuration is managed through `manifest.yml`.

### Package Examples

```bash
# Online package with version 5.0.0
$ ./scripts/package.sh --version 5.0.0

# Offline package with version 5.0.0
$ ./scripts/package.sh --version 5.0.0 --cached

# Package for specific stack
$ ./scripts/package.sh --stack cflinuxfs4 --cached

# Custom output location
$ ./scripts/package.sh --version 5.0.0 --cached --output /tmp/my-buildpack.zip
```

## Running Tests
To run the tests, do the following:

```bash
$ ./scripts/package.sh
$ ./scripts/unit.sh
$ BUILDPACK_FILE="$(pwd)/build/buildpack.zip" \
./scripts/integration.sh --platform docker --parallel true  --github-token MYTOKEN
```

[Running Cloud Foundry locally][] is useful for privately testing new features.

## Contributing
[Pull requests][] are welcome; see the [contributor guidelines][] for details.

## License
This buildpack is released under version 2.0 of the [Apache License][].

[`config/` directory]: config
[Apache License]: http://www.apache.org/licenses/LICENSE-2.0
[Cloud Foundry]: http://www.cloudfoundry.org
[contributor guidelines]: CONTRIBUTING.md
[disables `remote_downloads`]: docs/extending-caches.md#configuration
[Environment Variables]: http://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html#env-block
[GitHub's forking functionality]: https://help.github.com/articles/fork-a-repo
[Grails]: http://grails.org
[Groovy]: http://groovy.codehaus.org
[Play Framework]: http://www.playframework.com
[pull request]: https://help.github.com/articles/using-pull-requests
[Pull requests]: http://help.github.com/send-pull-requests
[Running Cloud Foundry locally]: https://github.com/cloudfoundry/cf-deployment/tree/master/iaas-support/bosh-lite
[Spring Boot]: http://projects.spring.io/spring-boot/
[Wikipedia]: https://en.wikipedia.org/wiki/YAML#Basic_components_of_YAML
