# Metric Writer Framework
The Metric Writer Framework causes an application to be automatically configured to work with a bound Metrics Forwarder Service.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound Metrics Forwarder service.
      <ul>
        <li>Existence of a Metrics Forwarder service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>metrics-forwarder</code> as a substring.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>metric_writer=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

The credential payload of the service may contain the following entries:

| Name | Description
| ---- | -----------
| `access_key` | The access key used to authenticate agains the endpoint
| `endpoint` | The endpoint

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/metric_writer.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Metric Writer repository index ([details][repositories]).
| `version` | The version of Metric Writer to use. Candidate versions can be found in [this listing][].

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/metric_writer.yml`]: ../config/metric_writer.yml
[repositories]: extending-repositories.md
[this listing]: https://java-buildpack.cloudfoundry.org/metric-writer/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
