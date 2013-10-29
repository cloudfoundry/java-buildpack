# AppDynamics Framework
The AppDynamics Framework causes an application to be automatically configured to work with a bound [AppDynamics Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound AppDynamics service. The existence of an AppDynamics service defined by the <a href="http://docs.cloudfoundry.com/docs/using/deploying-apps/environment-variable.html#VCAP_SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service name-version, name, label or tag with <code>app-dynamics</code> as a substring.
</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>appdynamics-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
When binding AppDynamics using a user-provided service, it must have name or tag with <code>app-dynamics</code> in it.  The credential payload can contain the following entries:

| Name | Description
| ---- | -----------
| `account-access-key` | (Optional) The account access key to use when authenticating with the controller
| `account-name` | (Optional) The account name to use when authenticating with the controller
| `host-name` | The controller host name
| `port` | (Optional) The controller port
| `ssl-enabled` | (Optional) Whether or not to use an SSL connection to the controller

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/appdynamics.yml`][] file.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the AppDynamics repository index ([details][repositories]).
| `version` | The version of AppDynamics to use. Candidate versions can be found in [this listing][].


[`config/appdynamics.yml`]: ../config/appdynamics.yml
[AppDynamics Service]: http://www.appdynamics.com
[Configuration and Extension]: ../README.md#Configuration-and-Extension
[repositories]: util-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/app-dynamics/index.yml
[version syntax]: util-repositories.md#version-syntax-and-ordering
