# Cloud Foundry Java Buildpack
[![Build Status](https://travis-ci.org/cloudfoundry/java-buildpack.png?branch=master)](https://travis-ci.org/cloudfoundry/java-buildpack)
[![Dependency Status](https://gemnasium.com/cloudfoundry/java-buildpack.png)](http://gemnasium.com/cloudfoundry/java-buildpack)
[![Code Climate](https://codeclimate.com/github/cloudfoundry/java-buildpack.png)](https://codeclimate.com/github/cloudfoundry/java-buildpack)

The `java-buildpack` is a [Cloud Foundry][cf] buildpack for running Java applications.  It is designed to run most Java applications with no additional configuration, but supports configuration of the standard components, and extension to add custom components.

[cf]: http://www.cloudfoundry.com

## Usage
To use this buildpack specify the URI of the repository when pushing an application to Cloud Foundry.

```bash
cf push --buildpack https://github.com/cloudfoundry/java-buildpack
```

## Configuration and Extension
The buildpack supports configuration and extension through the use of Git repository forking.  The easiest way to accomplish this is to use [GitHub's forking functionality][fork] to create a copy of this repository.  In that copy of the repository, make the required configuration and extension changes.  Then when pushing a Cloud Foundry application, use the URL of the new repository.  If the modifications are applicable to the Cloud Foundry community, please submit a [pull request][pull-request] with the changes.

[fork]: https://help.github.com/articles/fork-a-repo
[pull-request]: https://help.github.com/articles/using-pull-requests

## Additional Documentation
Additional documentation can be found by following the links below.

* [Design](docs/design.md)
* Standard Containers
	* [Java Main Class](docs/container-java-main.md) ([Configuration](docs/container-java-main.md#configuration))
	* [Play](docs/container-play.md)
	* [Tomcat](docs/container-tomcat.md) ([Configuration](docs/container-tomcat.md))
* Standard Frameworks
	* [`JAVA_OPTS`](docs/framework-java_opts.md) ([Configuration](docs/framework-java_opts.md#configuration))
* Standard JREs
	* [OpenJDK](docs/jre-openjdk.md) ([Configuration](docs/jre-openjdk.md#configuration))
* Extending
	* [Containers](docs/extending-containers.md)
	* [JREs](docs/extending-jres.md)
	* [Frameworks](docs/extending-frameworks.md)
* Utilities
	* [Caches](docs/util-caches.md)
	* [Repositories](docs/util-repositories.md)
	* [Repository Builders](docs/util-repository-builders.md)
	* [Test Applications](docs/util-test-applications.md)
