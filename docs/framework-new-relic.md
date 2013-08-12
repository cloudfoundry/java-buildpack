# New Relic Framework
The New Relic Framework causes an application to be automatically configured to work with a bound [New Relic Service][new_relic].

[new_relic]: https://newrelic.com

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
The container can be configured by modifying the [`config/newrelic.yml`][newrelic_yml] file.  The container uses the [`Repository` utility support][util_repositories] and so it supports the [version syntax][version_syntax] defined there.

[newrelic_yml]: ../config/newrelic.yml
[util_repositories]: util-repositories.md
[version_syntax]: util-repositories.md#version-syntax-and-ordering

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the New Relic repository index ([details][util_repositories]).
| `version` | The version of New Relic to use. Candidate versions can be found in [this listing][new_relic_index_yml].

[new_relic_index_yml]: http://download.pivotal.io.s3.amazonaws.com/new-relic/lucid/x86_64/index.yml
