# New Relic Agent Framework
The New Relic Agent Framework causes an application to be automatically configured to work with a bound [New Relic Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound New Relic service.
      <ul>
        <li>Existence of a New Relic service is defined as the <a href="http://docs.cloudfoundry.com/docs/using/deploying-apps/environment-variable.html#VCAP_SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>newrelic</code> as a substring.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>new-relic-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service (Optional)
Users may optionally provide their own New Relic service. A user-provided New Relic service must have a name or tag with `newrelic` in it so that the New Relic Agent Framework will automatically configure the application to work with the service.

The credential payload of the service may contain the following entries:

| Name | Description
| ---- | -----------
| `licenseKey` | The license key to use when authenticating

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/new_relic_agent.yml`][] file.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the New Relic repository index ([details][repositories]).
| `version` | The version of New Relic to use. Candidate versions can be found in [this listing][].

[Configuration and Extension]: ../README.md#Configuration-and-Extension
[`config/new_relic_agent.yml`]: ../config/new_relic_agent.yml
[New Relic Service]: https://newrelic.com
[repositories]: extending-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/new-relic/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
