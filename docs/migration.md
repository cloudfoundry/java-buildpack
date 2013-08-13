# Important notice: this buildpack has temporary restrictions which are detailed below.

# Migrating from cloudfoundry-buildpack-java

This buildpack supersedes the buildpack [`cloudfoundry-buildpack-java`][] but is not backward compatible with it, so users should read the following migration notes.

## Detect Processing

`cloudfoundry-buildpack-java` had different detection rules to this buildpack.  It performed a sequence of detection checks and acted upon the first check, if any, which passed. So it paid no attention to potentially ambiguous results.

This buildpack ensures that at most one _container_ (see [Design][] for the definition of this term) can be used to run an application and raises an error if more than one container can be used.

This buildpack supports all the types of application that `cloudfoundry-buildpack-java` supported.  However, this buildpack distinguishes between _containers_ and orthogonal _frameworks_ (see [Design][] for the definition of this term) whereas `cloudfoundry-buildpack-java` merged these concepts.

## Play Applications

`cloudfoundry-buildpack-java` allowed the Play `start` script (and the application's `lib` directory, although this is ignored during detection) to reside in an arbitrary subdirectory of the application directory. This buildpack requires the `start` script and the `lib` directory (or, equivalently, the `staged` directory) containing a Play JAR to reside directly in the application directory or in an immediate subdirectory of the application directory.

## Grails Applications

The support for Grails applications in this buildpack is identical to the support for standard web applications.

## Web Applications

`cloudfoundry-buildpack-java` allowed `web.xml` to reside in either of the directories `WEB-INF` or `webapps/ROOT/WEB-INF` whereas this buildpack requires `web.xml` to reside in the `WEB-INF` directory.

`cloudfoundry-buildpack-java` was hard-coded to use a specific version of Tomcat.  This buildpack is configured to use the latest update of a particular version of Tomcat. If a specific version of Tomcat is required, configure it in `config/tomcat.yml`.

`cloudfoundry-buildpack-java` automatically configured listeners with class names `org.apache.catalina.core.JreMemoryLeakPreventionListener` and `org.apache.catalina.mbeans.GlobalResourcesLifecycleListener`. `JreMemoryLeakPreventionListener` is not necessary since the memory leaks it prevents do not occur in Cloud Foundry. `GlobalResourcesLifecycleListener` is not necessary since Cloud Foundry applications are not managed using JMX.

<b>Temporary restriction:</b> `cloudfoundry-buildpack-java` automatically downloaded hard-coded versions of MySQL and PostGres database driver JARs and added them to the `lib` directory of the application, whereas this buildpack does not yet download or add database driver JARs.

## Java Main Applications

`cloudfoundry-buildpack-java` required Java main applications to contain a `.jar` or a `.class` file somewhere in the application directory tree whereas this buildpack requires either the `Main-Class` attribute to be set in `META-INF/MANIFEST.MF` or `java_main_class` to be configured in `config/main.yml`.

`cloudfoundry-buildpack-java` used a version of OpenJDK specified as the property `java.runtime.version` in a file `system.properties` residing anywhere in the application directory tree. If this property was not specified, `cloudfoundry-buildpack-java` used a hard-coded version of OpenJDK.  This buildpack is configured to use the latest update of a particular version of OpenJDK. If a specific version of OpenJDK is required, configure it in `config/openjdk.yml`. The version of OpenJDK may no longer be specified using a system property.

`cloudfoundry-buildpack-java` configured both the JVM maximum and minimum heap sizes to equal the application memory limit (`$MEMORY_LIMIT`). This buildpack supports a variety of memory size settings and memory heuristic settings for calculating defaults based on the application memory limit.  See [OpenJDK JRE configuration][] for details.

`cloudfoundry-buildpack-java` used to set the `java.io.tmpdir` Java system property to `$TMPDIR`.  If this is required, configure [`java_opts`][].


[`cloudfoundry-buildpack-java`]: https://github.com/cloudfoundry/cloudfoundry-buildpack-java
[Design]: design.md
[`java_opts`]: framework-java_opts.md#configuration
[OpenJDK JRE configuration]: jre-openjdk.md#configuration
