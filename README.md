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
	* [Tomcat Container](#tomcat) ([Tomcat](#tomcat-config))
	* [`JAVA_OPTS` Framework](#javaopts) ([Configuration](#javaopts-config))
* [Extending](#extending)
	* [JREs](#extending-jres)
	* [Containers](#extending-containers)
	* [Frameworks](#extending-framework)
* [Utilities](#utilities)
	* [Caches](#util-caches)
	* [Repositories](#util-repositories)
	* [Repository Builders](#util-repository-builders)
	* [Test Applications](#util-test-applications)

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
| | |
| --- | ---
| **Detection Tags** | `openjdk-<version>`

The OpenJDK JRE provides Java runtimes from the [OpenJDK][openjdk] project.  Versions of Java from the 1.6, 1.7, and 1.8 lines are available.  Unless otherwise configured, the version of Java that will be used is specified in [`config/openjdk.yml`][openjdk_yml].

[openjdk]: http://openjdk.java.net
[openjdk_yml]: config/openjdk.yml


<a name='openjdk-config'></a>
### Configuration
The OpenJDK JRE allows the configuration of the version of Java to use as well as the allocation of memory at runtime.  The JRE uses the [`Repository` utility support](#util-repositories) and so it supports the [version syntax](#util-repositories-version-syntax) defined there.

#### Version

| Name | Description
| ---- | -----------
| `java.runtime.version` | The version of Java runtime to use.  This value can either be an explicit version as found in [this listing][openjdk_index_yml] or by using wildcards.

[openjdk_index_yml]: http://download.pivotal.io.s3.amazonaws.com/openjdk/lucid/x86_64/index.yml

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

#### OpenJDK Memory Heuristics

The calculation of default memory sizes for OpenJDK is configured via YAML files in the buildpack's `config` directory.

The configuration contains a weighting between `0` and `1` corresponding to a proportion of the total memory specified when the application was pushed. The weightings should add up to `1`.

<a name='javamain'></a>
## Java Main Class Container
| | |
| --- | ---
| **Detection Criteria** | `Main-Class` attribute set in `META-INF/MANIFEST.MF` or `java.main.class` set
| **Detection Tags** | `java-main`

The Java Main Class Container allows applications that provide a class with a `main()` method in it to be run.  These applications are run with a command that looks like `./java/bin/java -cp . com.gopivotal.SampleClass`.

<a name='javamain-config'></a>
### Configuration

| Name | Description
| ---- | -----------
| `java.main.class` | The Java class name to run. Values containing whitespace are rejected with an error, but all others values appear without modification on the Java command line.  If not specified, the Java Manifest value of `Main-Class` is used.
| `java.main.args` | The arguments passed to the `main()` method when running the application. All values appear without modification on the Java command line.

<a name='tomcat'></a>
## Tomcat Container
| | |
| --- | ---
| **Detection Criteria** | Existence of a `WEB-INF/` folder in the application directory
| **Detection Tags** | `tomcat-<version>`

The Tomcat Container allows web application to be run.  These applications are run as the root web application in a Tomcat container.

<a name='tomcat-config'></a>
### Configuration
The Tomcat Container allows the configuration of the version of Tomcat to use.  The Container uses the [`Repository` utility support](#util-repositories) and so it supports the [version syntax](#util-repositories-version-syntax) defined there.

| Name | Description
| ---- | -----------
| `version` | The version of Tomcat to use

<a name="javaopts"></a>
## `JAVA_OPTS` Framework
| | |
| --- | ---
| **Detection Criteria** | `java.opts` set
| **Detection Tags** | `java-opts`

The `JAVA_OPTS` Framework contributes arbitrary Java options to the application at runtime.

<a name="javaopts"></a>
### Configuration

| Name | Description
| ---- | -----------
| `java.opts` | The Java options to use when running the application.  All values are used without modification when invoking the JVM.

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
# @option context [String] :java_home the directory that acts as +JAVA_HOME+
# @option context [Array<String>] :java_opts an array that Java options can be added to
# @option context [Hash] :configuration the configuration provided by the user
def initialize(context)

# Determines if the JRE can be used to run the application.
#
# @return [String, nil] If the JRE can be used to run the application, a +String+ that uniquely identifies the JRE
#                       (e.g. +openjdk-1.7.0_21+).  Otherwise, +nil+.
def detect

# Downloads and unpacks the JRE.  Status output written to +STDOUT+ is expected as part of this invocation.
#
# @return [void]
def compile

# Adds any JRE-specific options to +context[:java_opts]+.  Typically this includes memory configuration (heap, perm gen,
# etc.) but could be anything that a JRE needs to have configured.  As well, +context[:java_home]+ is expected to be
# updated with the value that the JRE has been unpacked to.  This must be done using the {String.concat} method to
# ensure that the value is accessible to other components.
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
# @option context [String] :java_home the directory that acts as +JAVA_HOME+
# @option context [Array<String>] :java_opts an array that Java options can be added to
# @option context [Hash] :configuration the configuration provided by the user
def initialize(context)

# Determines if the container can be used to run the application.
#
# @return [String, nil] If the container can be used to run the application, a +String+ that uniquely identifies the
#                       container (e.g. +tomcat-7.0.29+).  Otherwise, +nil+.
def detect

# Downloads and unpacks the container.  The container is expected to transform the application in whatever way
# necessary (e.g. moving files or creating symbolic links) to run it.  Status output written to +STDOUT+ is expected as
# part of this invocation.
#
# @return [void]
def compile

# Creates the command to run the application with.  The container is expected to read +context[:java_home]+ and
# +context[:java_opts]+ and take those values into account when creating the command.
#
# @return [String] the command to run the application with
def release
```

<a name='extending-frameworks'></a>
## Frameworks
To add a framework, the class file must be located in [`lib/java_buildpack/framework`][framework_dir].  The class must have the following methods:

[framework_dir]: lib/java_buildpack/framework

```ruby
# An initializer for the instance.
#
# @param [Hash<Symbol, String>] context A shared context provided to all components
# @option context [String] :app_dir the directory that the application exists in
# @option context [Array<String>] :java_opts an array that Java options can be added to
# @option context [Hash] :configuration the configuration provided by the user
def initialize(context)

# Determines if the framework can be applied to the application
#
# @return [String, nil] If the framework can be used to run the application, a +String+ that uniquely identifies the
#                       framework (e.g. +java-opts+).  Otherwise, +nil+.
def detect

# Transforms the application based on the framework.  Status output written to +STDOUT+ is expected as part of this
# invocation.
#
# @return [void]
def compile

# Adds any framework-specific options to +context[:java_opts]+.  Typically this includes any JRE configuration required
# by the framework, but could be anything that a framework needs to have configured.
#
# @return [void]
def release
```

# Utilities
The buildpack contains some utilities that might be of use to component developers.

<a name='util-caches'></a>
## Caches
Many components will want to cache large files that are downloaded for applications.  The buildpack provides a cache abstraction to encapsulate this caching behavior.  The cache abstraction is comprised of three cache types each with the same signature.

```ruby
# Retrieves an item from the cache.  Retrieval of the item uses the following algorithm:
#
# 1. Obtain an exclusive lock based on the URI of the item. This allows concurrency for different items, but not for
#    the same item.
# 2. If the the cached item does not exist, download from +uri+ and cache it, its +Etag+, and its +Last-Modified+
#    values if they exist.
# 3. If the cached file does exist, and the original download had an +Etag+ or a +Last-Modified+ value, attempt to
#    download from +uri+ again.  If the result is +304+ (+Not-Modified+), then proceed without changing the cached
#    item.  If it is anything else, overwrite the cached file and its +Etag+ and +Last-Modified+ values if they exist.
# 4. Downgrade the lock to a shared lock as no further mutation of the cache is possible.  This allows concurrency for
#    read access of the item.
# 5. Yield the cached file (opened read-only) to the passed in block. Once the block is complete, the file is closed
#    and the lock is released.
#
# @param [String] uri the uri to download if the item is not already in the cache.  Also used in the case where the
#                     item is already in the cache, to validate that the item is up to date
# @yieldparam [File] file the file representing the cached item. In order to ensure that the file is not changed or
#                    deleted while it is being used, the cached item can only be accessed as part of a block.
# @return [void]
def get(uri)

# Remove an item from the cache
#
# @param [String] uri the URI of the item to remove
# @return [void]
def evict(uri)
```

Usage of a cache might look like the following:

```ruby
JavaBuildpack::Util::DownloadCache.new().get(uri) do |file|
  YAML.load_file(file)
end
```

### `JavaBuildpack::Util::DownloadCache`
The [`DownloadCache`][download_cache] is the most generic of the three caches.  It allows you to create a cache that persists files any that write access is available.  The constructor signature looks the following:

```ruby
# Creates an instance of the cache that is backed by the filesystem rooted at +cache_root+
#
# @param [String] cache_root the filesystem root for downloaded files to be cached in
def initialize(cache_root = Dir.tmpdir)
```

[download_cache]: lib/java_buildpack/util/download_cache.rb

### `JavaBuildpack::Util::ApplicationCache`
The [`ApplicationCache`][application_cache] is a cache that persists files into the application cache passed to the `compile` script.  It examines `ARGV[1]` for the cache location and configures itself accordingly.

```ruby
# Creates an instance that is configured to use the application cache.  The application cache location is defined by
# the second argument (<tt>ARGV[1]</tt>) to the +compile+ script.
#
# @raise if the second argument (<tt>ARGV[1]</tt>) to the +compile+ script is +nil+
def initialize
```

[application_cache]: lib/java_buildpack/util/application_cache.rb

### `JavaBuildpack::Util::GlobalCache`
The [`GlobalCache`][global_cache] is a cache that persists files into the global cache passed to all scripts.  It examines `ENV['BUILDPACK_CACHE']` for the cache location and configures itself accordingly.

```ruby
# Creates an instance that is configured to use the global cache.  The global cache location is defined by the
# +BUILDPACK_CACHE+ environment variable
#
# @raise if the +BUILDPACK_CACHE+ environment variable is +nil+
def initialize
```

[global_cache]: lib/java_buildpack/util/global_cache.rb

<a name='util-repositories'></a>
## Repositories
Many components need to have access to multiple versions of binaries.  The buildpack provides a `Repository` abstraction to encapsulate version resolution and download URI creation.

### Repository Structure
The repository is an HTTP-accessible collection of files.  The repository root must contain an `index.yml` file ([example][example_index_yml]) that is a mapping of concrete versions to URIs.

```yaml
<version>: <URI>
```

An example filesystem might look like:

```
/index.yml
/openjdk-1.6.0_27.tar.gz
/openjdk-1.7.0_21.tar.gz
/openjdk-1.8.0_M7.tar.gz
```

[example_index_yml]: http://download.pivotal.io.s3.amazonaws.com/openjdk/lucid/x86_64/index.yml

### Usage

The main class used when dealing with a repository is [`JavaBuildpack::Repository::ConfiguredItem`][configured_item].  It provides a single method that is used to resolve a specific version and its URI.

```ruby
# Finds an instance of the file based on the configuration.
#
# @param [Hash] configuration the configuration
# @option configuration [String] :repository_root the root directory of the repository
# @option configuration [String] :version the version of the file to resolve
# @param [Block, nil] version_validator an optional version validation block
# @return [JavaBuildpack::Util::TokenizedVersion] the chosen version of the file
# @return [String] the URI of the chosen version of the file
def self.find_item(configuration, &version_validator)
```

Usage of the class might look like the following:

```ruby
version, uri = JavaBuildpack::Repository::ConfiguredItem.find_item(configuration)
```

or with version validation:

```ruby
version, uri = JavaBuildpack::Repository::ConfiguredItem.find_item(configuration) do |version|
  validate_version version
end
```

[configured_item]: lib/java_buildpack/repository/configured_item.rb

<a name='util-repositories-version-syntax'></a>
### Version Syntax and Ordering
Versions are composed of major, minor, micro, and optional qualifier parts (`<major>.<minor>.<micro>[_<qualifier>]`).  The major, minor, and micro parts must be numeric.  The qualifier part is composed of letters, digits, and hyphens.  The lexical ordering of the qualifier is:

1. hyphen
2. lowercase letters
3. uppercase letters
4. digits

### Version Wildcards
In addition to declaring a specific versions to use, you can also specify a bounded range of versions to use.  Appending the `+` symbol to a version prefix chooses the latest version that begins with the prefix.

| Example | Description
| ------- | -----------
| `1.+`   	| Selects the greatest available version less than `2.0.0`.
| `1.7.+` 	| Selects the greatest available version less than `1.8.0`.
| `1.7.0_+` | Selects the greatest available version less than `1.7.1`. Use this syntax to stay up to date with the latest security releases in a particular version.


<a name='util-repository-builders'></a>
## Repository Builders

The repositories that are currently referenced by the buildpack are easily replicated.  Simple scripts are used to populate the repositories in an automated fashion.

| Component | Builder
| --------- | -------
| `openjdk` | <https://github.com/cloudfoundry/builder-openjdk>
| `tomcat` | <https://github.com/cloudfoundry/builder-tomcat>

<a name='util-test-applications'></a>
## Test Applications

Simple test applications for various Java application types are provided in the [`java-test-applications`][java_test_applications] respository.  These are not intended to cover all code-paths.  Instead these are constantly changing representations of 'typical' applications.

[java_test_applications]: https://github.com/cloudfoundry/java-test-applications
