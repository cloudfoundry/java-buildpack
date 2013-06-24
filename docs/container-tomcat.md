# Tomcat Container
The Tomcat Container allows web application to be run.  These applications are run as the root web application in a Tomcat container.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a <tt>WEB-INF/</tt> folder in the application directory</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>tomcat-&lang;version&rang;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script
	

## Configuration
The container can be configured by modifying the [`config/tomcat.yml`][tomcat_yml] file.  The container uses the [`Repository` utility support][util_repositories] and so it supports the [version syntax][version_syntax] defined there.

[tomcat_yml]: ../config/tomcat.yml
[util_repositories]: util-repositories.md
[version_syntax]: util-repositories.md#version-syntax-and-ordering

| Name | Description
| ---- | -----------
| `version` | The version of Tomcat to use.  .  Candidate versions can be found in [this listing][tomcat_index_yml].

[tomcat_index_yml]: http://download.pivotal.io.s3.amazonaws.com/tomcat/lucid/x86_64/index.yml


## Supporting Functionality
Additional supporting functionality can be found in the [`java-buildpack-support][java_buildpack_support] Git repository.

[java_buildpack_support]: https://github.com/cloudfoundry/java-buildpack-support
