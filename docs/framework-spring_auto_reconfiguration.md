# Spring Auto-reconfiguration Framework
The Spring Auto-reconfiguration Framework causes an application to be automatically reconfigured to work with configured cloud services.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a <tt>spring-core*.jar</tt> file in the application directory</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>spring-auto-reconfiguration=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

If a `/WEB-INF/web.xml` file exists, the framework will modify it in addition to making the auto-reconfiguration JAR available on the classpath.  This modification consists of adding `org.cloudfoundry.reconfiguration.spring.CloudProfileApplicationContextInitializer`, `org.cloudfoundry.reconfiguration.spring.CloudPropertySourceApplicationContextInitializer`, and `org.cloudfoundry.reconfiguration.spring.CloudAutoReconfigurationApplicationContextInitializer` to the collection of `contextInitializerClasses`.

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/spring_auto_reconfiguration.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `enabled` | Whether to attempt auto-reconfiguration
| `repository_root` | The URL of the Auto-reconfiguration repository index ([details][repositories]).
| `version` | The version of Auto-reconfiguration to use. Candidate versions can be found in [this listing][].

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/spring_auto_reconfiguration.yml`]: ../config/spring_auto_reconfiguration.yml
[repositories]: extending-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/auto-reconfiguration/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
