# Contrast Security Agent Framework
The Contrast Security Agent Framework causes an application to be automatically configured to work with a bound [Contrast Security Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound Contrast Security service. The existence of an Contrast Security service defined by the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service name, label or tag with <code>contrast-security</code> as a substring.
</td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
When binding ContrastSecurity using a user-provided service, it must have name or tag with `contrast-security` in it. The credential payload can contain the following entries:

| Name | Description
| ---- | -----------
| `api_key` | Your user's api key
| `service_key` | Your user's service key
| `teamserver_url` | The base URL in which your user has access to and the URL to which the Agent will report. ex: https://app.contrastsecurity.com
| `username` | The account name to use when downloading the agent

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework has no user-configurable options.  The Contrast Security agent version is managed by the buildpack manifest.

[Contrast Security]: https://www.contrastsecurity.com
[Configuration and Extension]: ../README.md#configuration-and-extension
[Contrast Security Service]: https://www.contrastsecurity.com
