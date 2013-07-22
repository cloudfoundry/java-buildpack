# Play JPA Plugin Framework
The Play JPA Plugin Framework causes an application to be automatically reconfigured to work with configured cloud services.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>
        <ul>
            <li>An application is a Play 2.0 application</li>
            <li>An application uses the <tt>play-java-jpa<tt> plugin</li>
        </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>play-jpa-plugin-&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
The container can be configured by modifying the [`config/playjpaplugin.yml`][playjpaplugin_yml] file.  The container uses the [`Repository` utility support][util_repositories] and so it supports the [version syntax][version_syntax] defined there.

[playjpaplugin_yml]: ../config/playjpaplugin.yml
[util_repositories]: util-repositories.md
[version_syntax]: util-repositories.md#version-syntax-and-ordering

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Play JPA Plugin repository index ([details][util_repositories]).
| `version` | The version of the Play JPA Plugin to use. Candidate versions can be found in [this listing][play_jpa_plugin_index_yml].

[play_jpa_plugin_index_yml]: http://download.pivotal.io.s3.amazonaws.com/play-jpa-plugin/lucid/x86_64/index.yml
