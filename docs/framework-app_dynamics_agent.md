# AppDynamics Agent Framework
The AppDynamics Agent Framework causes an application to be automatically configured to work with a bound [AppDynamics Service][].  **Note:** This framework is disabled by default.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound AppDynamics service. The existence of an AppDynamics service defined by the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service name, label or tag with <code>app-dynamics</code> or <code>appdynamics</code> as a substring.
</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>app-dynamics-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
When binding AppDynamics using a user-provided service, it must have name or tag with `app-dynamics` or `appdynamics` in it. The credential payload can contain the following entries.  **Note:** Credentials marked as "(Optional)" may be required for some versions of the AppDynamics agent.  Please see the [AppDynamics Java Agent Configuration Properties][] for the version of the agent used by your application for more details.

| Name | Description
| ---- | -----------
| `account-access-key` | (Optional) The account access key to use when authenticating with the controller
| `account-name` | (Optional) The account name to use when authenticating with the controller
| `application-name` | (Optional) the application's name
| `host-name` | The controller host name
| `node-name` | (Optional) the application's node name
| `port` | (Optional) The controller port
| `ssl-enabled` | (Optional) Whether or not to use an SSL connection to the controller
| `tier-name` | (Optional) the application's tier name

To provide more complex values such as the `tier-name`, using the interactive mode when creating a user-provided service will manage the character escaping automatically. For example, the default `tier-name` could be set with a value of `Tier-$(expr "$VCAP_APPLICATION" : '.*instance_index[": ]*\([[:digit:]]*\).*')` to calculate a value from the Cloud Foundry instance index.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/app_dynamics_agent.yml`][] file in the buildpack fork. The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `default_application_name` | This is omitted by default but can be added to specify the application name in the AppDynamics dashboard. This can be overridden by an `application-name` entry in the credentials payload. If neither are supplied the default is the `application_name` as specified by Cloud Foundry.
| `default_node_name` | The default node name for this application in the AppDynamics dashboard. The default value is an expression that will be evaluated based on the `instance_index` of the application. This can be overridden by a `node-name` entry in the credentials payload.
| `default_tier_name` | This is omitted by default but can be added to specify the tier name for this application in the AppDynamics dashboard. This can be overridden by a `tier-name` entry in the credentials payload. If neither are supplied the default is the `application_name` as specified by Cloud Foundry.
| `repository_root` | The URL of the AppDynamics repository index ([details][repositories]).
| `version` | The version of AppDynamics to use. Candidate versions can be found in [this listing][].

### Additional Resources
The framework can also be configured by overlaying a set of resources on the default distribution. To do this, add files to the `resources/app_dynamics_agent` directory in the buildpack fork. For example, to override the default `app-agent-config.xml` add your custom file to `resources/app_dynamics_agent/conf/app-agent-config.xml`.

[`config/app_dynamics_agent.yml`]: ../config/app_dynamics_agent.yml
[AppDynamics Java Agent Configuration Properties]: https://docs.appdynamics.com/display/PRO42/Java+Agent+Configuration+Properties
[AppDynamics Service]: http://www.appdynamics.com
[Configuration and Extension]: ../README.md#configuration-and-extension
[repositories]: extending-repositories.md
[this listing]: https://packages.appdynamics.com/java/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
