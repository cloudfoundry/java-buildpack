# JRebel Agent Framework

This framework enables the use of [JRebel][jrebel] with deployed applications. Pushing any [JRebel Cloud/Remote][remoting] enabled application (containing `rebel-remote.xml`) will automatically download the latest version of [JRebel][jrebel] and set it up for use.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a <tt>rebel-remote.xml</tt> file inside the application archive. This file is present in every application that is configured to use <a href="http://manuals.zeroturnaround.com/jrebel/remoting/index.html" target="_blank">JRebel Cloud/Remote</a>.</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>jrebel-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script.

For more information regarding setup and configuration, please refer to the [JRebel with Pivotal Cloud Foundry tutorial][pivotal].

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/jrebel_agent.yml`][jrebelagentyml] file in a buildpack fork. The framework uses the [`Repository` utility support][repositories], supporting the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the JRebel repository index ([details][repositories]).
| `version` | The version of JRebel to use. Candidate versions can be found in [this listing][repoindex].

[jrebel]: http://zeroturnaround.com/software/jrebel/
[remoting]: http://manuals.zeroturnaround.com/jrebel/remoting/index.html
[pivotal]: http://manuals.zeroturnaround.com/jrebel/remoting/pivotal.html
[Configuration and Extension]: ../README.md#configuration-and-extension
[jrebelagentyml]: ../config/jrebel_agent.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
[repositories]: extending-repositories.md
[repoindex]: http://dl.zeroturnaround.com/jrebel/index.yml
