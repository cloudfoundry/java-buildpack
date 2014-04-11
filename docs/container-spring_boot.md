# Spring Boot Container
The Spring Boot Container allows [Spring Boot][s] applications, packaged `distZip`-style to be run.  **Note**  All styles of Sping Boot can be run (e.g. self-executable JAR, WAR file, `distZip`-style).  This is just explicit support for the `distZip` style.

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

## Configuration
The Spring Boot Container cannot be configured.

[d]: http://docs.spring.io/spring-boot/docs/1.0.1.RELEASE/reference/htmlsingle/#using-boot-gradle
[s]: http://projects.spring.io/spring-boot/
