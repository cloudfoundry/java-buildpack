# Auto Reconfiguration Framework
The Auto Reconfiguration Framework causes an application to be automatically reconfigured to work with configured cloud services.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a <tt>spring-core*.jar</tt> file in the application directory</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>auto-reconfiguration-&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

If a `/WEB-INF/web.xml` file exists, the framework will modify it in addition to making the auto reconfiguration JAR available on the classpath.  These modifications include:

1. Augmenting `contextConfigLocation`.  The function starts be enumerating the current `contextConfigLocation`s. If none exist, a default configuration is created with `/WEB-INF/application-context.xml` or `/WEB-INF/<servlet-name>-servlet.xml` as the default.  An additional location is then added to the collection of locations; `classpath:META- INF/cloud/cloudfoundry-auto-reconfiguration-context.xml` if the `ApplicationContext` is XML-based, `org.cloudfoundry.reconfiguration.spring.web.CloudAppAnnotationConfigAutoReconfig` if the `ApplicationContext` is annotation-based.
2. Augmenting `contextInitializerClasses`.  The function starts by enumerating the current `contextInitializerClasses`.  If none exist, a default configuration is created with no value as the default. The `org.cloudfoundry.reconfiguration.spring.CloudApplicationContextInitializer` class is then added to the collection of classes.

## Configuration
The container can be configured by modifying the [`config/autoreconfiguration.yml`][autoreconfiguration_yml] file.  The container uses the [`Repository` utility support][util_repositories] and so it supports the [version syntax][version_syntax] defined there.

[autoreconfiguration_yml]: ../config/autoreconfiguration.yml
[util_repositories]: util-repositories.md
[version_syntax]: util-repositories.md#version-syntax-and-ordering

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Auto Reconfiguration repository index ([details][util_repositories]).
| `version` | The version of Auto Reconfiguration to use. Candidate versions can be found in [this listing][auto_reconfiguration_index_yml].

[auto_reconfiguration_index_yml]: http://download.pivotal.io.s3.amazonaws.com/auto-reconfiguration/lucid/x86_64/index.yml
