# Container Customizer Framework
The Container Customizer Framework modifies the configuration of an embedded Tomcat container in a Spring Boot WAR file.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Application is a Spring Boot WAR file</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>container-customizer=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework has no user-configurable buildpack options.  The Container Customizer version is managed by the buildpack manifest.

[Configuration and Extension]: ../README.md#configuration-and-extension
