# AppDynamics Agent Framework
The AppDynamics Agent Framework causes an application to be automatically configured to work with a bound [AppDynamics Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound AppDynamics service. The existence of an AppDynamics service defined by the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service name, label or tag with <code>app-dynamics</code> as a substring.
</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>app-dynamics-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
When binding AppDynamics using a user-provided service, it must have name or tag with `app-dynamics` in it.  The credential payload can contain the following entries:

| Name | Description
| ---- | -----------
| `account-access-key` | (Optional) The account access key to use when authenticating with the controller
| `account-name` | (Optional) The account name to use when authenticating with the controller
| `host-name` | The controller host name
| `port` | (Optional) The controller port
| `ssl-enabled` | (Optional) Whether or not to use an SSL connection to the controller
| `tier-name` | (Optional) the application's tier name

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/app_dynamics_agent.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `default_tier_name` | The default tier name for this application in the AppDynamics dashboard.  This can be overridden with a `tier-name` entry in the credentials payload.
| `repository_root` | The URL of the AppDynamics repository index ([details][repositories]).
| `version` | The version of AppDynamics to use. Candidate versions can be found in [this listing][].

### Additional Resources
The framework can also be configured by overlaying a set of resources on the default distribution.  To do this, add files to the `resources/app_dynamics_agent` directory in the buildpack fork.  For example, to override the default `app-agent-config.xml` add your custom file to `resources/app_dynamics_agent/conf/app-agent-config.xml`.

[`config/app_dynamics_agent.yml`]: ../config/app_dynamics_agent.yml
[AppDynamics Service]: http://www.appdynamics.com
[Configuration and Extension]: ../README.md#configuration-and-extension
[repositories]: extending-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/app-dynamics/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
