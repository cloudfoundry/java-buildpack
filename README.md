# Cloud Foundry Java Buildpack
[![Build Status](https://travis-ci.org/cloudfoundry/java-buildpack.png?branch=master)](https://travis-ci.org/cloudfoundry/java-buildpack)
[![Dependency Status](https://gemnasium.com/cloudfoundry/java-buildpack.png)](http://gemnasium.com/cloudfoundry/java-buildpack)
[![Code Climate](https://codeclimate.com/github/cloudfoundry/java-buildpack.png)](https://codeclimate.com/github/cloudfoundry/java-buildpack)

The `java-buildpack` is a [Cloud Foundry][] buildpack for running Java applications.  It is designed to run most Java applications with no additional configuration, but supports configuration of the standard components, and extension to add custom components.

## Usage
To use this buildpack specify the URI of the repository when pushing an application to Cloud Foundry:

    cf push --buildpack https://github.com/cloudfoundry/java-buildpack

The total amount of memory available is specified when the application is pushed. See [Memory](docs/jre-openjdk.md#Memory) for information on how this determines the memory available to a Java application.

## Configuration and Extension
The buildpack supports configuration and extension through the use of Git repository forking.  The easiest way to accomplish this is to use [GitHub's forking functionality][] to create a copy of this repository.  Make the required configuration and extension changes in the copy of the repository.  Then specify the URL of the new repository when pushing Cloud Foundry applications.  If the modifications are generally applicable to the Cloud Foundry community, please submit a [pull request][] with the changes.

To learn how to configure various properties of the buildpack, follow the "Configuration" links below. More information on extending the buildpack is available [here](docs/extending.md).

## Additional Documentation
* [Design](docs/design.md)
* [Migrating from the Previous Java Buildpack](docs/migration.md)
* [Security](docs/security.md)
* Standard Containers
	* [Groovy](docs/container-groovy.md) ([Configuration](docs/container-groovy.md#configuration))
	* [Java Main Class](docs/container-java-main.md) ([Configuration](docs/container-java-main.md#configuration))
	* [Play](docs/container-play.md)
	* [Spring Boot CLI](docs/container-spring-boot-cli.md) ([Configuration](docs/container-spring-boot-cli.md#configuration))
	* [Tomcat](docs/container-tomcat.md) ([Configuration](docs/container-tomcat.md#configuration))
* Standard Frameworks
	* [`JAVA_OPTS`](docs/framework-java_opts.md) ([Configuration](docs/framework-java_opts.md#configuration))
	* [AppDynamics](docs/framework-app-dynamics.md) ([Configuration](docs/framework-app-dynamics.md#configuration))
	* [New Relic](docs/framework-new-relic.md) ([Configuration](docs/framework-new-relic.md#configuration))
	* [Play Auto Reconfiguration](docs/framework-play-auto-reconfiguration.md) ([Configuration](docs/framework-play-auto-reconfiguration.md#configuration))
	* [Play JPA Plugin](docs/framework-play-jpa-plugin.md) ([Configuration](docs/framework-play-jpa-plugin.md#configuration))
	* [Spring Auto Reconfiguration](docs/framework-spring-auto-reconfiguration.md) ([Configuration](docs/framework-spring-auto-reconfiguration.md#configuration))
	* [Spring Insight](docs/framework-spring-insight.md) ([Configuration](docs/framework-spring-insight.md#configuration))
* Standard JREs
	* [OpenJDK](docs/jre-openjdk.md) ([Configuration](docs/jre-openjdk.md#configuration))
* [Extending](docs/extending.md)
* Utilities
	* [Caches](docs/util-caches.md) ([Configuration](docs/util-caches.md#configuration))
	* [Logging](docs/logging.md) ([Configuration](docs/logging.md#configuration))
	* [Repositories](docs/util-repositories.md)
	* [Other Utiltities](docs/util-other.md)
	* [Repository Builder](docs/util-repository-builder.md)
	* [Test Applications](docs/util-test-applications.md)
	* [System Tests](docs/util-system-tests.md)

## Running Tests
To run the tests, do the following:

```bash
bundle install
bundle exec rake
```

If you want to use the RubyMine debugger, you may need to [install additional gems][] by issuing:

```bash
bundle install --gemfile Gemfile.rubymine-debug
```

[Installing Cloud Foundry on Vagrant][] is useful for privately testing new features.

## Contributing
[Pull requests][] are welcome; see the [contributor guidelines][] for details.

## License
This buildpack is released under version 2.0 of the [Apache License][].

[Apache License]: http://www.apache.org/licenses/LICENSE-2.0
[Cloud Foundry]: http://www.cloudfoundry.com
[contributor guidelines]: CONTRIBUTING.md
[GitHub's forking functionality]: https://help.github.com/articles/fork-a-repo
[install additional gems]: http://stackoverflow.com/questions/11732715/how-do-i-install-ruby-debug-base19x-on-mountain-lion-for-intellij
[pull request]: https://help.github.com/articles/using-pull-requests
[Pull requests]: http://help.github.com/send-pull-requests
[Installing Cloud Foundry on Vagrant]: http://blog.cloudfoundry.com/2013/06/27/installing-cloud-foundry-on-vagrant/
