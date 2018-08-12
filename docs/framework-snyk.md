# Snyk Framework
The Snyk Framework causes an application to be automatically configured to work with a bound [Snyk Service][].
Binding an application to the service will cause the buildpack to check for vulnerable dependencies and break the build process
if found any, for a given severity threshold.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a bound Snyk service.
      <ul>
        <li>Existence of a Snyk service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>snyk</code> as a substring.</li>
      </ul>
      <ul>
        <li>Existence of an <code>apiToken</code> value Configuration.
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>snyk</td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service (Optional)
Users may optionally provide their own Snyk service. A user-provided Snyk service must have a name or tag with `snyk` in it so that the Snyk Framework will automatically configure the application to work with the service.

The credential payload of the service may contain the following entries:

| Name | Description
| ---- | -----------
| `apiToken` | The snyk api token used to authenticate against the api endpoint.
| `apiUrl` | (Optional) The url of the snyk api endpoint. Should be of the form `https://my.snyk.server:port/api`. Defaults to `https://snyk.io/api`
| `orgName` | (Optional) The organization for the snyk service to use. If not provided, snyk api will use the user's default organization.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured with additional (optional) values by modifying the [`config/snyk.yml`][] file in the buildpack fork.

| Name | Description
| ---- | -----------
| `api_token` | Same as `apiToken` in credentials payload. If defined both in config and in credentials, config will take precedence.
| `api_url` | Same as `apiUrl` in credentials payload. If defined both in config and in credentials, config will take precedence.
| `org_name` | Same as `orgName` in credentials payload. If defined both in config and in credentials, config will take precedence.
| `dont_break_build` | If set to `true` will tell Snyk to continue with the application deployment even though Snyk found vulnerabilties.
| `severity_threshold` | Tells Snyk the severity threshold of vulnerabilities found above which to fail the deployment.

[Snyk Service]: https://snyk.io
[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/snyk.yml`]: ../config/snyk.yml
