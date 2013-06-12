# Cloud Foundry Java Buildpack
[![Build Status](https://travis-ci.org/cloudfoundry/java-buildpack.png?branch=master)](https://travis-ci.org/cloudfoundry/java-buildpack)
[![Dependency Status](https://gemnasium.com/cloudfoundry/java-buildpack.png)](http://gemnasium.com/cloudfoundry/java-buildpack)
[![Code Climate](https://codeclimate.com/github/cloudfoundry/java-buildpack.png)](https://codeclimate.com/github/cloudfoundry/java-buildpack)

The `java-buildpack` is a [Cloud Foundry][cf] buildpack for running Java applications.  It is designed to run most Java applications with no additional configuration, but supports configuration of the standard components, and extension to add custom components.

[cf]: http://www.cloudfoundry.com

* [Usage](#usage) ([Configuration](#config))
* [Design](#design)
* [Standard Components](#standard-components)
	* [OpenJDK JRE](#openjdk) ([Configuration](#openjdk-config))
	* [Java Main Class Container](#javamain) ([Configuration](#javamain-config))
* [Extending](#extending)
	* [JREs](#extending-jres)
	* [Containers](#extending-containers)

---

# Usage
To use this buildpack specify the URI of the repository when pushing an application to Cloud Foundry.

```bash
cf push --buildpack https://github.com/cloudfoundry/java-buildpack
```

<a name='config'></a>
## Configuration and Extension
The buildpack supports configuration and extension through the use of Git repository forking.  The easiest way to accomplish this is to use [GitHub's forking functionality][fork] to create a copy of this repository.  In that copy of the repository, make the required configuration and extension changes.  Then when pushing a Cloud Foundry application, use the URL of the new repository.  If the modifications are applicable to the Cloud Foundry community, please submit a [pull request][pull-request] with the changes.

[fork]: https://help.github.com/articles/fork-a-repo
[pull-request]: https://help.github.com/articles/using-pull-requests

### `system.properties`
Components are configured by setting key-value pairs in a `system.properties` file.  The `system.properties` file can exist anywhere within the pushed artifact's file system.

# Design
The buildpack is designed as a collection of components.  These components are divided into three types; _JREs_, _Containers_, and _Frameworks_.

### JRE Components
JRE components represent the JRE that will be used when running an application.  This type of component is responsible for determining which JRE should be used, downloading and unpacking that JRE, and resolving any JRE-specific options that should be used at runtime.

Only a single JRE component can be used to run an application.  If more than one JRE can be used, an error will be raised and application deployment will fail.  In this case, the `java.runtime.vendor` property in `system.properties` must be set to a value that will cause a single JRE component to be used.

### Container Components
Container components represent the way that an application will be run.  Container types range from traditional application servers and servlet containers to simple Java `main()` method execution.  This type of component is responsible for determining which container should be used, downloading and unpacking that container, and producing the command that will be executed by Cloud Foundry at runtime.

Only a single container component can run an application.  If more than one container can be used, an error will be raised and application deployment will fail.

### Framework Components
Framework components represent additional behavior or transformations used when an application is run.  Framework types include the downloading of JDBC JARs for bound services and automatic reconfiguration of `DataSource`s in Spring configuration to match bound services.  This type of component is responsible for determining which frameworks are required, transforming the application, and contributing any additional options that should be used at runtime.

Any number of framework components can be used when running an application.

# Standard Components
The buildpack contributes a number of standard components that enable most Java applications to run.

<a name='openjdk'></a>
## OpenJDK JRE
**Criteria:** `java.runtime.vendor` set to `openjdk`

The OpenJDK JRE provides Java runtimes from the [OpenJDK][openjdk] project.  Versions of Java from the 1.6, 1.7, and 1.8 lines are available.  If the version to use is not configured in `system.properties`, the latest version from the `1.7.0` line is chosen.

[openjdk]: http://openjdk.java.net

### JRE Version Syntax and Ordering
JREs versions are composed of major, minor, micro, and optional qualifier parts (`<major>.<minor>.<micro>[_<qualifier>]`).  The major, minor, and micro parts must be numeric.  The qualifier part is composed of letters, digits, and hyphens.  The lexical ordering of the qualifier is:

1. hyphen
2. lowercase letters
3. uppercase letters
4. digits

### JRE Version Wildcards
In addition to declaring a specific version of JRE to use, you can also specify a bounded range of JRES to use.  Appending the `+` symbol to a version prefix chooses the latest JRE that begins with the prefix.

| Example | Description
| ------- | -----------
| `1.+`   	| Selects the greatest available version less than `2.0.0`.
| `1.7.+` 	| Selects the greatest available version less than `1.8.0`.
| `1.7.0_+` | Selects the greatest available version less than `1.7.1`. Use this syntax to stay up to date with the latest security releases in a particular version.

<a name='openjdk-config'></a>
### Configuration
The OpenJDK JRE allows the configuration of the version of Java to use as well as the allocation of memory at runtime.

#### Version

| Name | Description
| ---- | -----------
| `java.runtime.version` | The version of Java runtime to use.  This value can either be an explicit version as found in [this listing][index_yml] or by using wildcards.

[index_yml]: http://jres.gopivotal.com.s3.amazonaws.com/lucid/x86_64/openjdk/index.yml

#### Memory

| Name | Description
| ---- | -----------
| `java.heap.size` | The Java maximum heap size to use. For example, a value of `64m` will result in the java command line option `-Xmx64m`. Values containing whitespace are rejected with an error, but all others values appear without modification on the java command line appended to `-Xmx`.
| `java.metaspace.size` | The Java maximum Metaspace size to use. This is applicable to versions of OpenJDK from 1.8 onwards. For example, a value of `128m` will result in the java command line option `-XX:MaxMetaspaceSize=128m`. Values containing whitespace are rejected with an error, but all others values appear without modification on the java command line appended to `-XX:MaxMetaspaceSize=`.
| `java.permgen.size` | The Java maximum PermGen size to use. This is applicable to versions of OpenJDK earlier than 1.8. For example, a value of `128m` will result in the java command line option `-XX:MaxPermSize=128m`. Values containing whitespace are rejected with an error, but all others values appear without modification on the java command line appended to `-XX:MaxPermSize=`.
| `java.stack.size` | The Java stack size to use. For example, a value of `256k` will result in the java command line option `-Xss256k`. Values containing whitespace are rejected with an error, but all others values appear without modification on the java command line appended to `-Xss`.

#### Default Memory Sizes

If some memory sizes are not specified using the above properties, default values are provided. For maximum heap, Metaspace, or PermGen size, the default value is based on a proportion of the total memory specified when the application was pushed. For stack size, the default value is one megabyte.

If any memory sizes are specified which are not equal to the default value, the proportionate defaults are adjusted accordingly. The default stack size is never adjusted from the default value.  

<a name='javamain'></a>
## Java Main Class Container
**Criteria:** `Main-Class` attribute set in `META-INF/MANIFEST.MF` or `java.main.class` set

The Java Main Class Container allows applications that provide a class with a `main()` method in it to be run.  These applications are run with a command that looks like `./java/bin/java -cp . com.gopivotal.SampleClass`.

<a name='javamain-config'></a>
### Configuration

| Name | Description
| ---- | -----------
| `java.main.class` | The Java class name to run. Values containing whitespace are rejected with an error, but all others values appear without modification on the java command line.  If not specified, the Java Manifest value of `Main-Class` is used.


# Extending
The buildpack is designed to be extended by specifying components in [`config/components.yml`][components_yml].  The values listed in this file correspond to Ruby class names that will be instantiated and called.  In order for these classes to be instantiated, the files containing them must be located in specific directories in the repository.

[components_yml]: config/components.yml

<a name='extending-jres'></a>
## JREs
To add a JRE, the class file must be located in [`lib/java_buildpack/jre`][jre_dir].  The class must have the following methods:

[jre_dir]: lib/java_buildpack/jre

```ruby
# An initializer for the instance.
#
# @param [Hash<Symbol, String>] context A shared context provided to all components
# @option context [String] :app_dir the directory that the application exists in
# @option context [Array<String>] :java_opts an array that Java options can be added to
# @option context [Hash] :system_properties the properties provided by the user
def initialize(context = {})

# Determines if the JRE can be used to run the application.
#
# @return [String, nil]  If the JRE can be used to run the application, a +String+ that uniquely identifies the JRE
#                         (e.g. +jre-openjdk-1.7.0_21+).  Otherwise, +nil+.
def detect

# Downloads and unpacks the JRE.  The JRE is expected to be unpacked such that +JAVA_HOME+ is +.java+.  Status output
# written to +STDOUT+ is expected as part of this invocation.
#
# @return [void]
def compile

# Adds any JRE-specific options to +context[:java_opts]+.  Typically this includes memory configuration (heap, perm gen,
# etc.) but could be anything that a JRE needs to have configured.
#
# @return [void]
def release
```

<a name='extending-containers'></a>
## Containers
To add a container, the class file must be located in [`lib/java_buildpack/container`][container_dir].  The class must have the following methods

[container_dir]: lib/java_buildpack/container

```ruby
# An initializer for the instance.
#
# @param [Hash<Symbol, String>] context A shared context provided to all components
# @option context [String] :app_dir the directory that the application exists in
# @option context [Array<String>] :java_opts an array that Java options can be added to
# @option context [Hash] :system_properties the properties provided by the user
def initialize(context = {})

# Determines if the container can be used to run the application.
#
# @return [String, nil]  If the container can be used to run the application, a +String+ that uniquely identifies the
#                         container (e.g. +tomcat-7.0.29+).  Otherwise, +nil+.
def detect

# Downloads and unpacks the container.  The container is expected to transform the application in whatever way
# necessary (e.g. moving files or creating symbolic links) to run it.  Status output written to +STDOUT+ is expected as
# part of this invocation.
#
# @return [void]
def compile

# Creates the command to run the application with.  The container is expected to read +context[:java_opts]+ and take
# those values into account when creating the command.
#
# @return [String] the command to run the application with
def release
```

## OpenJDK Memory Heuristics

The calculation of default memory sizes for OpenJDK is configured via YAML files in the buildpack's `config` directory.

The configuration contains a weighting between 0 and 1 corresponding to a proportion of the total memory specified
when the application was pushed. The weightings should add up to 1.
