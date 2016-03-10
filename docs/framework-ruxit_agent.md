# Ruxit Agent Framework
The Ruxit Agent Framework causes an application to be automatically configured to work with a bound [Ruxit Service][] instance (Free trials available).

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound Ruxit service.
      <ul>
        <li>Existence of a Ruxit service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>ruxit</code> as a substring.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>ruxit-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service (Optional)
Users may optionally provide their own Ruxit service. A user-provided Ruxit service must have a name or tag with `ruxit` in it so that the Ruxit Agent Framework will automatically configure the application to work with the service.

The credential payload of the service may contain the following entries:

| Name | Description
| ---- | -----------
| `tenant` | Your Ruxit tenant ID is the unique identifier of your Ruxit environment. You can find it easily by looking at the URL in your browser when you are logged into your Ruxit environment. The subdomain `{tenant}` in `https://{tenant}.live.ruxit.com` represents your tenant ID.
| `tenanttoken` | The token for your Ruxit environment. You can find it in the deploy Ruxit section within your environment.
| `server` | (Optional) The Ruxit server connection URL to connect to. Use `host:port` format for a specific port number. Uses `https://{tenant}.live.ruxit.com:443/communication` by default.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

Any environment variables with a `RUXIT_` prefix will be relayed to the droplet to allow full configuration of the agent.

The framework can be configured by modifying the [`config/ruxit_agent.yml`][] file in the buildpack fork. The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Ruxit repository index ([details][repositories]).
| `version` | The version of Ruxit to use. Candidate versions can be found in [this listing][].

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/ruxit_agent.yml`]: ../config/ruxit_agent.yml
[Ruxit Service]: https://ruxit.com
[repositories]: extending-repositories.md
[this listing]: http://download.ruxit.com/agent/paas/cloudfoundry/java/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
