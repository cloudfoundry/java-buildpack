# Spring Boot Container
The Spring Boot Container allows [Spring Boot][s] applications, packaged `distZip`-style to be run.  **Note**  All styles of Spring Boot can be run (e.g. self-executable JAR, WAR file, `distZip`-style).  This is just explicit support for the `distZip` style.

<table>
  <tr>
    <td><strong>Detection Criteria</strong></td>
    <td>The <tt>lib/spring-boot-.*.jar</tt> file exists in either the top-level directory or an immediate subdirectory of the application.</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>spring-boot=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

The container expects to run the application creating by running [`gradle distZip`][d] in an application built with the Spring Boot Gradle plugin.

If the application uses Spring, [Spring profiles][] can be specified by setting the [`SPRING_PROFILES_ACTIVE`][] environment variable. This is automatically detected and used by Spring. The Spring Auto-reconfiguration Framework will specify the `cloud` profile in addition to any others. 

## Configuration
The Spring Boot Container cannot be configured.

[d]: http://docs.spring.io/spring-boot/docs/1.0.1.RELEASE/reference/htmlsingle/#using-boot-gradle
[s]: http://projects.spring.io/spring-boot/
[Spring profiles]:http://blog.springsource.com/2011/02/14/spring-3-1-m1-introducing-profile/
[`SPRING_PROFILES_ACTIVE`]: http://static.springsource.org/spring/docs/3.1.x/javadoc-api/org/springframework/core/env/AbstractEnvironment.html#ACTIVE_PROFILES_PROPERTY_NAME
