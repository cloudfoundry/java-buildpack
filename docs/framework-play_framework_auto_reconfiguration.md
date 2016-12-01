# Play Framework Auto-reconfiguration Framework
The Play Framework Auto-reconfiguration Framework causes an application to be automatically reconfigured to work with configured cloud services.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>An application is a Play Framework application</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>play-framework-auto-reconfiguration=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/play_framework_auto_reconfiguration.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.


| Name | Description
| ---- | -----------
| `enabled` | Whether to attempt auto-reconfiguration
| `repository_root` | The URL of the Auto-reconfiguration repository index ([details][repositories]).
| `version` | The version of Auto-reconfiguration to use. Candidate versions can be found in [this listing][].

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/play_framework_auto_reconfiguration.yml`]: ../config/config/play_framework_auto_reconfiguration.yml
[repositories]: extending-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/auto-reconfiguration/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
