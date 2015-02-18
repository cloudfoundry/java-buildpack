# JRebel Agent Framework
The JRebel Agent Framework causes an application to be automatically configured to work with an IDE using [JRebel][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of the `rebel.xml` and `rebel-remote.xml` files in either the root or `WEB-INF/classes` directory or the application.</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>jrebel-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/jrebel_agent.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the JRebel repository index ([details][repositories]).
| `version` | The version of Jrebel to use. Candidate versions can be found in [this listing][].

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/jrebel_agent.yml`]: ../config/jrebel_agent.yml
[JRebel]: http://zeroturnaround.com/software/jrebel/
[repositories]: extending-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/jrebel/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
