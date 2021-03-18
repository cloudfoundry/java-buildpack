# Tomcat Container
The Tomcat Container allows servlet 2 and 3 web applications to be run.  These applications are run as the root web application in a Tomcat container.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a <tt>WEB-INF/</tt> folder in the application directory and <a href="container-java_main.md">Java Main</a> not detected</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>tomcat-instance=&lang;version&rang;</tt>, <tt>tomcat-lifecycle-support=&lang;version&rang;</tt>, <tt>tomcat-logging-support=&lang;version&rang;</tt>, <tt>tomcat-redis-store=&lang;version&rang;</tt> <i>(optional)</i>, <tt>tomcat-external_configuration=&lang;version&rang;</tt> <i>(optional)</i></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

If the application uses Spring, [Spring profiles][] can be specified by setting the [`SPRING_PROFILES_ACTIVE`][] environment variable. This is automatically detected and used by Spring. The Spring Auto-reconfiguration Framework will specify the `cloud` profile in addition to any others.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The container can be configured by modifying the [`config/tomcat.yml`][] file in the buildpack fork.  The container uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `access_logging_support.repository_root` | The URL of the Tomcat Access Logging Support repository index ([details][repositories]).
| `access_logging_support.version` | The version of Tomcat Access Logging Support to use. Candidate versions can be found in [this listing](http://download.pivotal.io.s3.amazonaws.com/tomcat-access-logging-support/index.yml).
| `access_logging_support.access_logging` | Set to `enabled` to turn on the access logging support. Default is `disabled`.
| `geode_store.repository_root` | The URL of the Geode Store repository index ([details][repositories]).
| `geode_store.version` | The version of Geode Store to use. Candidate versions can be found in [this listing](https://java-buildpack-tomcat-gemfire-store.s3-us-west-2.amazonaws.com/index.yml).
| `lifecycle_support.repository_root` | The URL of the Tomcat Lifecycle Support repository index ([details][repositories]).
| `lifecycle_support.version` | The version of Tomcat Lifecycle Support to use. Candidate versions can be found in [this listing](http://download.pivotal.io.s3.amazonaws.com/tomcat-lifecycle-support/index.yml).
| `logging_support.repository_root` | The URL of the Tomcat Logging Support repository index ([details][repositories]).
| `logging_support.version` | The version of Tomcat Logging Support to use. Candidate versions can be found in [this listing](http://download.pivotal.io.s3.amazonaws.com/tomcat-logging-support/index.yml).
| `redis_store.connection_pool_size` | The Redis connection pool size.  Note that this is per-instance, not per-application.
| `redis_store.database` | The Redis database to connect to.
| `redis_store.repository_root` | The URL of the Redis Store repository index ([details][repositories]).
| `redis_store.timeout` | The Redis connection timeout (in milliseconds).
| `redis_store.version` | The version of Redis Store to use. Candidate versions can be found in [this listing](http://download.pivotal.io.s3.amazonaws.com/redis-store/index.yml).
| `tomcat.context_path` | The context path to expose the application at.
| `tomcat.repository_root` | The URL of the Tomcat repository index ([details][repositories]).
| `tomcat.version` | The version of Tomcat to use. Candidate versions can be found in [this listing](http://download.pivotal.io.s3.amazonaws.com/tomcat/index.yml).
| `tomcat.external_configuration_enabled` | Set to `true` to be able to supply an external Tomcat configuration. Default is `false`.
| `external_configuration.version` | The version of the External Tomcat Configuration to use. Candidate versions can be found in the the repository that you have created to house the External Tomcat Configuration. Note: It is required the external configuration to allow symlinks.
| `external_configuration.repository_root` | The URL of the External Tomcat Configuration repository index ([details][repositories]).

### Common configurations
The version of Tomcat can be configured by setting an environment variable.

```
$ cf set-env my-application JBP_CONFIG_TOMCAT '{tomcat: { version: 7.0.+ }}'
```

The context path that an application is deployed at can be configured by setting an environment variable.

```
$ cf set-env my-application JBP_CONFIG_TOMCAT '{tomcat: { context_path: /first-segment/second-segment }}'
```


### Additional Resources
The container can also be configured by overlaying a set of resources on the default distribution.  To do this follow one of the options below.

#### Buildpack Fork
Add files to the `resources/tomcat` directory in the buildpack fork.  For example, to override the default `logging.properties` add your custom file to `resources/tomcat/conf/logging.properties`.

#### External Tomcat Configuration
Supply a repository with an external Tomcat configuration.

Example in a manifest.yml

```yaml
env:
  JBP_CONFIG_TOMCAT: '{ tomcat: { external_configuration_enabled: true }, external_configuration: { repository_root: "http://repository..." } }'
```

The artifacts that the repository provides must be in TAR format and must follow the Tomcat archive structure:

```
tomcat
|- conf
   |- context.xml
   |- server.xml
   |- web.xml
   |...
```

Notes:
* It is required the external configuration to allow symlinks. For more information check [Tomcat 7 configuration] or [Tomcat 8 configuration].
* `JasperListener` is removed in Tomcat 8 so you should not add it to the server.xml.

## Session Replication
By default, the Tomcat instance is configured to store all Sessions and their data in memory.  Under certain circumstances it my be appropriate to persist the Sessions and their data to a repository.  When this is the case (small amounts of data that should survive the failure of any individual instance), the buildpack can automatically configure Tomcat to do so by binding an appropriate service.

### Redis
To enable Redis-based session replication, simply bind a Redis service containing a name, label, or tag that has `session-replication` as a substring.

### Tanzu GemFire for VMs
To enable session state caching on Tanzu GemFire for VMs, bind to a Tanzu GemFire service instance whose name either ends in `-session-replication` or is tagged with `session-replication`.

Service instances can be created with a tag:

```sh
$ cf create-service p-cloudcache my-service-instance -t session-replication
```

or existing service instances can be given a tag:

```sh
$ cf update-service new-service-instance -t session-replication
```

## Managing Entropy
Entropy from `/dev/random` is used heavily to create session ids, and on startup for initializing `SecureRandom`, which can then cause instances to fail to start in time (see the [Tomcat wiki]). Also, the entropy is shared so it's possible for a single app to starve the DEA of entropy and cause apps in other containers that make use of entropy to be blocked.
If this is an issue then configuring `/dev/urandom` as an alternative source of entropy may help. It is unlikely, but possible, that this may cause some security issues which should be taken in to account.

Example in a manifest.yml
```
env:
  JAVA_OPTS: -Djava.security.egd=file:///dev/urandom
```

## Supporting Functionality
Additional supporting functionality can be found in the [`java-buildpack-support`][] Git repository.

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/tomcat.yml`]: ../config/tomcat.yml
[`java-buildpack-support`]: https://github.com/cloudfoundry/java-buildpack-support
[repositories]: extending-repositories.md
[Spring profiles]:http://blog.springsource.com/2011/02/14/spring-3-1-m1-introducing-profile/
[`SPRING_PROFILES_ACTIVE`]: http://docs.spring.io/spring/docs/4.0.0.RELEASE/javadoc-api/org/springframework/core/env/AbstractEnvironment.html#ACTIVE_PROFILES_PROPERTY_NAME
[Tomcat wiki]: http://wiki.apache.org/tomcat/HowTo/FasterStartUp
[version syntax]: extending-repositories.md#version-syntax-and-ordering
[Tomcat 7 configuration]: http://tomcat.apache.org/tomcat-7.0-doc/config/context.html#Standard_Implementation
[Tomcat 8 configuration]: http://tomcat.apache.org/tomcat-8.0-doc/config/resources.html#Common_Attributes
