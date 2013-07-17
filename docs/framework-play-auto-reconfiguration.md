# Play Auto Reconfiguration Framework
The Play Auto Reconfiguration Framework causes an application to be automatically reconfigured to work with configured cloud services.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>An application is a Play application</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>play-auto-reconfiguration-&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
The container can be configured by modifying the [`config/playautoreconfiguration.yml`][playautoreconfiguration_yml] file.  The container uses the [`Repository` utility support][util_repositories] and so it supports the [version syntax][version_syntax] defined there.

[playautoreconfiguration_yml]: ../config/playautoreconfiguration.yml
[util_repositories]: util-repositories.md
[version_syntax]: util-repositories.md#version-syntax-and-ordering

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Auto Reconfiguration repository index ([details][util_repositories]).
| `version` | The version of Auto Reconfiguration to use. Candidate versions can be found in [this listing][auto_reconfiguration_index_yml].

[auto_reconfiguration_index_yml]: http://download.pivotal.io.s3.amazonaws.com/auto-reconfiguration/lucid/x86_64/index.yml
