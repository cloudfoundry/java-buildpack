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
    <td><strong>Tags</strong></td><td><tt>play-jpa-plugin=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/playjpaplugin.yml`][] file.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Play JPA Plugin repository index ([details][repositories]).
| `version` | The version of the Play JPA Plugin to use. Candidate versions can be found in [this listing][].

[Configuration and Extension]: ../README.md#Configuration-and-Extension
[`config/playjpaplugin.yml`]: ../config/playjpaplugin.yml
[repositories]: util-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/play-jpa-plugin/index.yml
[version syntax]: util-repositories.md#version-syntax-and-ordering
