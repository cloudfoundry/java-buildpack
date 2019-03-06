# Elastic APM Agent Framework

The Elastic APM Agent Framework causes an application to be automatically configured to work with [Elastic APM][]. Pushing any [JRebel Cloud/Remote][] enabled application (containing `rebel-remote.xml`) will automatically download the latest version of [JRebel][] and set it up for use.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a <tt>rebel-remote.xml</tt> file inside the application archive. This file is present in every application that is configured to use <a href="http://manuals.zeroturnaround.com/jrebel/remoteserver/index.html" target="_blank">JRebel Cloud/Remote</a>.</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>jrebel-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

For more information regarding setup and configuration, please refer to the [Elastic APM with Pivotal Cloud Foundry tutorial][pivotal].

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/elastic_apm_agent.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Elastic APM repository index ([details][repositories]).
| `version` | The version of Elastic APM to use. Candidate versions can be found in [this listing][].
| `enabled` | Whether to activate Elastic APM (upon the presence of `rebel-remote.xml`) or not.

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/elastic_apm_agent.yml`]: ../config/elastic_apm_agent.yml
[JRebel Cloud/Remote]: http://manuals.zeroturnaround.com/jrebel/remoteserver/index.html
[JRebel]: http://zeroturnaround.com/software/jrebel/
[pivotal]: http://manuals.zeroturnaround.com/jrebel/remoteserver/pivotal.html
[repositories]: extending-repositories.md
[this listing]: http://dl.zeroturnaround.com/jrebel/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
