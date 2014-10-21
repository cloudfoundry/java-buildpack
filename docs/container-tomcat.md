# Tomcat Container
The Tomcat Container allows servlet 2 and 3 web applications to be run.  These applications are run as the root web application in a Tomcat container.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a <tt>WEB-INF/</tt> folder in the application directory and <a href="container-java_main.md">Java Main</a> not detected</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>tomcat-instance=&lang;version&rang;</tt>, <tt>tomcat-lifecycle-support=&lang;version&rang;</tt>, <tt>tomcat-logging-support=&lang;version&rang;</tt> <tt>tomcat-redis-store=&lang;version&rang;</tt> <i>(optional)</i></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

If the application uses Spring, [Spring profiles][] can be specified by setting the [`SPRING_PROFILES_ACTIVE`][] environment variable. This is automatically detected and used by Spring. The Spring Auto-reconfiguration Framework will specify the `cloud` profile in addition to any others. 

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The container can be configured by modifying the [`config/tomcat.yml`][] file in the buildpack fork.  The container uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `lifecycle_support.repository_root` | The URL of the Tomcat Lifecycle Support repository index ([details][repositories]).
| `lifecycle_support.version` | The version of Tomcat Lifecycle Support to use. Candidate versions can be found in [this listing](http://download.pivotal.io.s3.amazonaws.com/tomcat-lifecycle-support/index.yml).
| `logging_support.repository_root` | The URL of the Tomcat Logging Support repository index ([details][repositories]).
| `logging_support.version` | The version of Tomcat Logging Support to use. Candidate versions can be found in [this listing](http://download.pivotal.io.s3.amazonaws.com/tomcat-logging-support/index.yml).
| `access_logging_support.repository_root` | The URL of the Tomcat Access Logging Support repository index ([details][repositories]).
| `access_logging_support.version` | The version of Tomcat Access Logging Support to use. Candidate versions can be found in [this listing](http://download.pivotal.io.s3.amazonaws.com/tomcat-access-logging-support/index.yml).
| `access_logging_support.access_logging` | Set to `enabled` to turn on the access logging support. Default is `disabled`.
| `redis_store.connection_pool_size` | The Redis connection pool size.  Note that this is per-instance, not per-application.
| `redis_store.database` | The Redis database to connect to.
| `redis_store.repository_root` | The URL of the Redis Store repository index ([details][repositories]).
| `redis_store.timeout` | The Redis connection timeout (in milliseconds).
| `redis_store.version` | The version of Redis Store to use. Candidate versions can be found in [this listing](http://download.pivotal.io.s3.amazonaws.com/redis-store/index.yml).
| `tomcat.repository_root` | The URL of the Tomcat repository index ([details][repositories]).
| `tomcat.version` | The version of Tomcat to use. Candidate versions can be found in [this listing](http://download.pivotal.io.s3.amazonaws.com/tomcat/index.yml).

### Additional Resources
The container can also be configured by overlaying a set of resources on the default distribution.  To do this, add files to the `resources/tomcat` directory in the buildpack fork.  For example, to override the default `logging.properties` add your custom file to `resources/tomcat/conf/logging.properties`.

## Session Replication
By default, the Tomcat instance is configured to store all Sessions and their data in memory.  Under certain cirmcumstances it my be appropriate to persist the Sessions and their data to a repository.  When this is the case (small amounts of data that should survive the failure of any individual instance), the buildpack can automatically configure Tomcat to do so.

### Redis
To enable Redis-based session replication, simply bind a Redis service containing a name, label, or tag that has `session-replication` as a substring.


## Supporting Functionality
Additional supporting functionality can be found in the [`java-buildpack-support`][] Git repository.

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/tomcat.yml`]: ../config/tomcat.yml
[`java-buildpack-support`]: https://github.com/cloudfoundry/java-buildpack-support
[repositories]: extending-repositories.md
[Spring profiles]:http://blog.springsource.com/2011/02/14/spring-3-1-m1-introducing-profile/
[`SPRING_PROFILES_ACTIVE`]: http://docs.spring.io/spring/docs/4.0.0.RELEASE/javadoc-api/org/springframework/core/env/AbstractEnvironment.html#ACTIVE_PROFILES_PROPERTY_NAME
[version syntax]: extending-repositories.md#version-syntax-and-ordering
