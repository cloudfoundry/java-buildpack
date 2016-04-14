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

The framework can be configured by modifying the [`config/container_customizer.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Container Customizer repository index ([details][repositories]).
| `version` | The version of Container Customizer to use. Candidate versions can be found in [this listing][].

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/container_customizer.yml`]: ../config/container_customizer.yml
[repositories]: extending-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/container-customizer/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
