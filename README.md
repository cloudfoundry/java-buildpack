# Cloud Foundry Java Buildpack

The `java-buildpack` is a [Cloud Foundry][] buildpack for running JVM-based applications.  It is designed to run many JVM-based applications ([Grails][], [Groovy][], Java Main, [Play Framework][], [Spring Boot][], and Servlet) with no additional configuration, but supports configuration of the standard components, and extension to add custom components.

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
The buildpack default configuration can be overridden with an environment variable matching the configuration file you wish to override minus the `.yml` extension and with a prefix of `JBP_CONFIG`. It is not possible to add new configuration properties and properties with `nil` or empty values will be ignored by the buildpack (in this case you will have to extend the buildpack, see below). The value of the variable should be valid inline yaml, referred to as "flow style" in the yaml spec ([Wikipedia][] has a good description of this yaml syntax). For example, to change the default version of Java to 11 and adjust the memory heuristics apply this environment variable to the application.

```bash
$ cf set-env my-application JBP_CONFIG_OPEN_JDK_JRE '{ jre: { version: 11.+ }, memory_calculator: { stack_threads: 25 } }'
```

If the key or value contains a special character such as `:` it should be escaped with double quotes. For example, to change the default repository path for the buildpack.

```bash
$ cf set-env my-application JBP_CONFIG_REPOSITORY '{ default_repository_root: "http://repo.example.io" }'
```

If the key or value contains an environment variable that you want to bind at runtime you need to escape it from your shell. For example, to add command line arguments containing an environment variable to a [Java Main](docs/container-java_main.md) application.

```bash
$ cf set-env my-application JBP_CONFIG_JAVA_MAIN '{ arguments: "--server.port=9090 --foo=bar" }'
```

An example of configuration is to specify a `javaagent` that is packaged within an application.

```bash
$ cf set-env my-application JAVA_OPTS '-javaagent:app/META-INF/myagent.jar -Dmyagent.config_file=app/META-INF/my_agent.conf'
```

Environment variable can also be specified in the applications `manifest` file. For example, to specify an environment variable in an applications manifest file that disables Auto-reconfiguration.

```bash
env:
  JBP_CONFIG_SPRING_AUTO_RECONFIGURATION: '{ enabled: false }'
```

This final example shows how to change the version of Tomcat that is used by the buildpack with an environment variable specified in the applications manifest file.

```bash
env:
  JBP_CONFIG_TOMCAT: '{ tomcat: { version: 8.0.+ } }'
```

See the [Environment Variables][] documentation for more information.

To learn how to configure various properties of the buildpack, follow the "Configuration" links below.

The buildpack supports extension through the use of Git repository forking. The easiest way to accomplish this is to use [GitHub's forking functionality][] to create a copy of this repository.  Make the required extension changes in the copy of the repository. Then specify the URL of the new repository when pushing Cloud Foundry applications. If the modifications are generally applicable to the Cloud Foundry community, please submit a [pull request][] with the changes. More information on extending the buildpack is available [here](docs/extending.md).

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
  * [Checkmarx IAST Agent](docs/framework-checkmarx_iast_agent.md) ([Configuration](docs/framework-checkmarx_iast_agent.md#configuration))
  * [Client Certificate Mapper](docs/framework-client_certificate_mapper.md) ([Configuration](docs/framework-client_certificate_mapper.md#configuration))
  * [Container Customizer](docs/framework-container_customizer.md) ([Configuration](docs/framework-container_customizer.md#configuration))
  * [Container Security Provider](docs/framework-container_security_provider.md) ([Configuration](docs/framework-container_security_provider.md#configuration))
  * [Contrast Security Agent](docs/framework-contrast_security_agent.md) ([Configuration](docs/framework-contrast_security_agent.md#configuration))
  * [DataDog](docs/framework-datadog_javaagent.md) ([Configuration](docs/framework-datadog_javaagent.md#configuration)
  * [Debug](docs/framework-debug.md) ([Configuration](docs/framework-debug.md#configuration))
  * [Elastic APM Agent](docs/framework-elastic_apm_agent.md) ([Configuration](docs/framework-elastic_apm_agent.md#configuration))
  * [Dynatrace SaaS/Managed OneAgent](docs/framework-dynatrace_one_agent.md) ([Configuration](docs/framework-dynatrace_one_agent.md#configuration))
  * [Google Stackdriver Debugger](docs/framework-google_stackdriver_debugger.md) ([Configuration](docs/framework-google_stackdriver_debugger.md#configuration))
  * [Google Stackdriver Profiler](docs/framework-google_stackdriver_profiler.md) ([Configuration](docs/framework-google_stackdriver_profiler.md#configuration))
  * [Introscope Agent](docs/framework-introscope_agent.md) ([Configuration](docs/framework-introscope_agent.md#configuration))
  * [JaCoCo Agent](docs/framework-jacoco_agent.md) ([Configuration](docs/framework-jacoco_agent.md#configuration))
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
  * [Spring Auto Reconfiguration](docs/framework-spring_auto_reconfiguration.md) ([Configuration](docs/framework-spring_auto_reconfiguration.md#configuration))
  * [Spring Insight](docs/framework-spring_insight.md)
  * [SkyWalking Agent](docs/framework-sky_walking_agent.md) ([Configuration](docs/framework-sky_walking_agent.md#configuration))
  * [Takipi Agent](docs/framework-takipi_agent.md) ([Configuration](docs/framework-takipi_agent.md#configuration))
  * [YourKit Profiler](docs/framework-your_kit_profiler.md) ([Configuration](docs/framework-your_kit_profiler.md#configuration))
* Standard JREs
  * [Azul Zulu](docs/jre-zulu_jre.md) ([Configuration](docs/jre-zulu_jre.md#configuration))
  * [Azul Platform Prime](docs/jre-zing_jre.md) ([Configuration](docs/jre-zing_jre.md#configuration))
  * [GraalVM](docs/jre-graal_vm_jre.md) ([Configuration](docs/jre-graal_vm_jre.md#configuration))
  * [IBM® SDK, Java™ Technology Edition](docs/jre-ibm_jre.md) ([Configuration](docs/jre-ibm_jre.md#configuration))
  * [OpenJDK](docs/jre-open_jdk_jre.md) ([Configuration](docs/jre-open_jdk_jre.md#configuration))
  * [Oracle](docs/jre-oracle_jre.md) ([Configuration](docs/jre-oracle_jre.md#configuration))
  * [SapMachine](docs/jre-sap_machine_jre.md) ([Configuration](docs/jre-sap_machine_jre.md#configuration))
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
The buildpack can be packaged up so that it can be uploaded to Cloud Foundry using the `cf create-buildpack` and `cf update-buildpack` commands.  In order to create these packages, the rake `package` task is used.

Note that this process is not currently supported on Windows. It is possible it will work, but it is not tested, and no additional functionality has been added to make it work.

### Online Package
The online package is a version of the buildpack that is as minimal as possible and is configured to connect to the network for all dependencies.  This package is about 50K in size.  To create the online package, run:

```bash
$ bundle install
$ bundle exec rake clean package
...
Creating build/java-buildpack-cfd6b17.zip
```

### Offline Package
The offline package is a version of the buildpack designed to run without access to a network.  It packages the latest version of each dependency (as configured in the [`config/` directory][]) and [disables `remote_downloads`][]. This package is about 180M in size.  To create the offline package, use the `OFFLINE=true` argument:

To pin the version of dependencies used by the buildpack to the ones currently resolvable use the `PINNED=true` argument. This will update the [`config/` directory][] to contain exact version of each dependency instead of version ranges.
```bash
$ bundle install
$ bundle exec rake clean package OFFLINE=true PINNED=true
...
Creating build/java-buildpack-offline-cfd6b17.zip
```

Only packages referenced in the [`config/components.yml` file](config/components.yml) will be cached. Additional packages may be added using the `ADD_TO_CACHE` argument. The value of `ADD_TO_CACHE` should be set to the name of a `.yml` file in the [`config/` directory][] with the `.yml` file extension omitted (e.g. `sap_machine_jre`). Multiple file names may be separated by commas. This is useful to add additional JREs. These additional components will not be enabled by default and must be explicitly enabled in the application with the `JBP_CONFIG_COMPONENTS` environment variable.

```bash
$ bundle install
$ bundle exec rake clean package OFFLINE=true ADD_TO_CACHE=sap_machine_jre,ibm_jre
...
Caching https://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/8.0.6.26/linux/x86_64/ibm-java-jre-8.0-6.26-x86_64-archive.bin
Caching https://github.com/SAP/SapMachine/releases/download/sapmachine-11.0.10/sapmachine-jre-11.0.10_linux-x64_bin.tar.gz
...
Creating build/java-buildpack-offline-cfd6b17.zip
```

### Package Versioning
Keeping track of different versions of the buildpack can be difficult.  To help with this, the rake `package` task puts a version discriminator in the name of the created package file.  The default value for this discriminator is the current Git hash (e.g. `cfd6b17`).  To change the version when creating a package, use the `VERSION=<VERSION>` argument:

```bash
$ bundle install
$ bundle exec rake clean package VERSION=2.1
...
Creating build/java-buildpack-2.1.zip
```

### Packaging Caveats

1. When pinning versions, only the default JRE version is pinned. There is [special handling to package additional versions of a JRE](https://github.com/cloudfoundry/java-buildpack/blob/main/rakelib/dependency_cache_task.rb#L128-L144) and the way this works, it will pick the latest version at the time you package not at the time of the version's release.
2. The `index.yml` file for a dependencie is packaged in the buildpack cache when building offline buildpacks. The `index.yml` file isn't versioned with the release, so if you package an offline buildpack for an older release, it will pull the current `index.yml`, not the one from the time of the release. This can result in errors if a user tells the buildpack to install the latest version of a default dependency, because the latest version is calculated from the `index.yml` file which has more recent versions than what are packaged in the offline buildpack. Because of #1, this only impacts the default JRE. Non-default JREs always package the most recent version, which is also the most recent version in `index.yml` at the time you package the offline buildpack.
3. Because of #1 and #2, it is not present to accurately reproduce packages of the buildpack, after releases have been cut. If building pinning or offline buildpacks, it is suggested to build them as soon as possible after a release is cut and save the produced artifact.

See [#892](https://github.com/cloudfoundry/java-buildpack/issues/892#issuecomment-880212806) for additional details.

## Running Tests
To run the tests, do the following:

```bash
$ bundle install
$ bundle exec rake
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
