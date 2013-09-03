# New Relic Framework
The New Relic Framework causes an application to be automatically configured to work with a bound [New Relic Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound New Relic service</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>new-relic-&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/newrelic.yml`][] file.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the New Relic repository index ([details][repositories]).
| `version` | The version of New Relic to use. Candidate versions can be found in [this listing][].

[Configuration and Extension]: ../README.md#Configuration-and-Extension
[`config/newrelic.yml`]: ../config/newrelic.yml
[New Relic Service]: https://newrelic.com
[repositories]: util-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/new-relic/index.yml
[version syntax]: util-repositories.md#version-syntax-and-ordering
