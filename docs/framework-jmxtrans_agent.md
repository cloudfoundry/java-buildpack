# Jmxtrans Agent Framework
The Jmxtrans Agent Framework causes an application to be automatically configured to work with a bound [Jmxtrans service][].  **Note:** This framework is disabled by default.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound Jmxtrans service.
      <ul>
        <li>Existence of a Jmxtrans service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>jmxtrans</code> as a substring.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>jmxtrans-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/jmxtrans_agent.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Introscope Agent repository index ([details][repositories]).
| `version` | The version of Jmxtrans Agent to use.
| `enabled` | Whether to enable Jmxtrans Agent.


[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/jmxtrans_agent.yml`]: ../config/jmxtrans_agent.yml
[Jmxtrans service]: https://github.com/jmxtrans/jmxtrans/wiki
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
