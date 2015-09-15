# Spring Boot CLI Container
The Spring Boot CLI Container runs one or more Groovy (i.e. `*.groovy`) files using Spring Boot CLI.

<table>
  <tr>
    <td><strong>Detection Criteria</strong></td>
    <td><ul>
      <li>The application has one or more <tt>.groovy</tt> files, and</li>
      <li>All the application's <tt>.groovy</tt> files are POGOs (a POGO contains one or more classes), and</li>
      <li>None of the application's <tt>.groovy</tt> files contain a <tt>main</tt> method, and</li>
      <li>None of the application's <tt>.groovy</tt> files contain a shebang (<tt>#!</tt>) declaration, and</li>
      <li>The application does not have a <tt>WEB-INF</tt> subdirectory of its root directory.</li>
    </ul></td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>spring-boot-cli=&lang;version&rang;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script.

If the application uses Spring, [Spring profiles][] can be specified by setting the [`SPRING_PROFILES_ACTIVE`][] environment variable. This is automatically detected and used by Spring. The Spring Auto-reconfiguration Framework will specify the `cloud` profile in addition to any others. 

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The container can be configured by modifying the [`config/spring_boot_cli.yml`][] file in the buildpack fork.  The container uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Spring Boot CLI repository index ([details][repositories]).
| `version` | The version of Spring Boot CLI to use. Candidate versions can be found in [this listing][].

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/spring_boot_cli.yml`]: ../config/spring_boot_cli.yml
[repositories]: extending-repositories.md
[Spring profiles]:http://blog.springsource.com/2011/02/14/spring-3-1-m1-introducing-profile/
[`SPRING_PROFILES_ACTIVE`]: http://static.springsource.org/spring/docs/3.1.x/javadoc-api/org/springframework/core/env/AbstractEnvironment.html#ACTIVE_PROFILES_PROPERTY_NAME
[this listing]: http://download.pivotal.io.s3.amazonaws.com/spring-boot-cli/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
