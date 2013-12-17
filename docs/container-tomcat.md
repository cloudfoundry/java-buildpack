# Tomcat Container
The Tomcat Container allows servlet 2 and 3 web applications to be run.  These applications are run as the root web application in a Tomcat container.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a <tt>WEB-INF/</tt> folder in the application directory and <a href="container-java_main.md">Java Main</a> not detected</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>tomcat=&lang;version&rang;</tt>, <tt>tomcat-buildpack-support=&lang;version&rang;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

In order to specify [Spring profiles][], set the [`SPRING_PROFILES_ACTIVE`][] environment variable.  This is automatically detected and used by Spring.

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The container can be configured by modifying the [`config/tomcat.yml`][] file.  The container uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Tomcat repository index ([details][repositories]).
| `version` | The version of Tomcat to use. Candidate versions can be found in [this listing][].

## Supporting Functionality
Additional supporting functionality can be found in the [`java-buildpack-support`][] Git repository.

[Configuration and Extension]: ../README.md#Configuration-and-Extension
[`config/tomcat.yml`]: ../config/tomcat.yml
[`java-buildpack-support`]: https://github.com/cloudfoundry/java-buildpack-support
[repositories]: extending-repositories.md
[Spring profiles]:http://blog.springsource.com/2011/02/14/spring-3-1-m1-introducing-profile/
[`SPRING_PROFILES_ACTIVE`]: http://docs.spring.io/spring/docs/4.0.0.RELEASE/javadoc-api/org/springframework/core/env/AbstractEnvironment.html#ACTIVE_PROFILES_PROPERTY_NAME
[this listing]: http://download.pivotal.io.s3.amazonaws.com/tomcat/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
