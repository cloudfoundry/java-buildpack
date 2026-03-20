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


### Default Configuration
The buildpack includes default Tomcat configuration files that are embedded at compile time. These defaults provide Cloud Foundry-optimized settings including:

- HTTP/2 support
- Access logging valve configuration
- Remote IP valve for proper `x-forwarded-proto` handling
- Application startup failure detection
- Error report valve with disabled server info disclosure

The default configuration files are located in `src/java/resources/files/tomcat/conf/`:
- `server.xml` - Main Tomcat server configuration
- `context.xml` - Default context configuration
- `logging.properties` - Logging configuration

These defaults are automatically applied and can be overridden using external configuration (see below).

#### Customizing Default Configuration via Fork
To customize the default Tomcat configuration across all applications using your buildpack:

1. Fork the java-buildpack repository
2. Modify the configuration files in `src/java/resources/files/tomcat/conf/`
3. Build and package your custom buildpack
4. Upload the custom buildpack to your Cloud Foundry foundation

This approach is useful for operators who want to enforce organization-wide Tomcat settings.

### Additional Resources
The container can also be configured using external Tomcat configuration as described below.

#### External Tomcat Configuration
Supply a repository with an external Tomcat configuration that will be downloaded during staging.

The buildpack will automatically download the configuration from the specified `repository_root` URL without requiring any changes to the buildpack's manifest.yml.

Example in a manifest.yml:

```yaml
env:
  JBP_CONFIG_TOMCAT: '{ tomcat: { external_configuration_enabled: true }, external_configuration: { repository_root: "https://your-repository.example.com/tomcat-config", version: "1.4.0" } }'
```

**How it works:**

1. The buildpack downloads `{repository_root}/index.yml` which contains a mapping of versions to download URLs
2. It looks up the URL for the requested version in the index
3. It downloads the configuration archive from that URL
4. It extracts and overlays the configuration onto the Tomcat installation

**Repository Structure:**

Your repository must contain an `index.yml` file at the root with the following format:

```yaml
1.0.0: https://your-repository.example.com/tomcat-config/tomcat-config-1.0.0.tar.gz
1.1.0: https://your-repository.example.com/tomcat-config/tomcat-config-1.1.0.tar.gz
1.2.0: https://your-repository.example.com/tomcat-config/tomcat-config-1.2.0.tar.gz
1.3.0: https://your-repository.example.com/tomcat-config/tomcat-config-1.3.0.tar.gz
1.4.0: https://your-repository.example.com/tomcat-config/tomcat-config-1.4.0.tar.gz
```

The buildpack will fetch `https://your-repository.example.com/tomcat-config/index.yml`, look up version `1.4.0`, and download the corresponding tar.gz file.

**Archive Format Requirements:**

The configuration archives must be in TAR.GZ format and must follow this structure:

```
tomcat-external-configuration-1.4.0.tar.gz
└── conf/
    ├── context.xml
    ├── server.xml
    ├── web.xml
    ├── logging.properties
    └── ...
```

The buildpack will extract the archive directly into the Tomcat installation directory, overlaying the configuration files.

**Configuration Options:**

| Option | Description | Default |
|--------|-------------|---------|
| `external_configuration_enabled` | Enable external configuration | `false` |
| `repository_root` | Base URL of the configuration repository (required when enabled) | none |
| `version` | Version of the external configuration to download | `1.0.0` |

**Notes:**
* The external configuration must allow symlinks. For more information check [Tomcat 7 configuration] or [Tomcat 8 configuration].
* `JasperListener` is removed in Tomcat 8 so you should not add it to the server.xml.
* The buildpack first checks if `tomcat-external-configuration` is defined in the buildpack's manifest.yml (for forked buildpacks). If not found, it downloads from the `repository_root` using the index.yml approach.
* If the download fails or the version is not found in index.yml, the build will fail. Ensure your repository URL is accessible and the version exists in the index.

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
