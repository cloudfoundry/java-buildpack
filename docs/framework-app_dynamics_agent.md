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
When binding AppDynamics using a user-provided service, it must have name or tag with `app-dynamics` or `appdynamics` in it. The credential payload can contain the following entries.

| Name | Description
| ---- | -----------
| `account-access-key` | The account access key to use when authenticating with the controller
| `account-name` | The account name to use when authenticating with the controller
| `host-name` | The controller host name
| `port` | The controller port
| `ssl-enabled` | Whether or not to use an SSL connection to the controller
| `application-name` | (Optional) the application's name
| `node-name` | (Optional) the application's node name
| `tier-name` | (Optional) the application's tier name

To provide more complex values such as the `tier-name`, using the interactive mode when creating a user-provided service will manage the character escaping automatically. For example, the default `tier-name` could be set with a value of `Tier-$(expr "${VCAP_APPLICATION}" : '.*instance_index[": ]*\([[:digit:]]*\).*')` to calculate a value from the Cloud Foundry instance index.

**Note:** Some credentials were previously marked as "(Optional)" as requirements have changed across versions of the AppDynamics agent.  Please see the [AppDynamics Java Agent Configuration Properties][] for the version of the agent used by your application for more details.

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
The framework can also be configured by overlaying a set of resources on the default distribution.  To do this follow one of the options below.

Configuration files are created in this order:

1. Default AppDynamics configuration
2. Buildpack default configuration is taken from `resources/app_dynamics_agent/default`
3. External Configuration if configured
4. Local Configuration if configured
5. Buildpack Fork if it exists

#### Buildpack Fork
Add files to the `resources/app_dynamics_agent` directory in the buildpack fork.  For example, to override the default `app-agent-config.xml` add your custom file to `resources/app_dynamics_agent/<version>/conf/app-agent-config.xml`.

#### External Configuration
Set `APPD_CONF_HTTP_URL` to an HTTP or HTTPS URL which points to the directory where your configuration files exist. You may also include a user and password in the URL, like `https://user:pass@example.com`.

The Java buildpack will take the URL to the directory provided and attempt to download the following files from that directory:

- `logging/log4j2.xml` 
- `logging/log4j.xml`
- `app-agent-config.xml` 
- `controller-info.xml`
- `service-endpoint.xml` 
- `transactions.xml` 
- `custom-interceptors.xml`
- `custom-activity-correlation.xml`

Any file successfully downloaded will be copied to the configuration directory. The buildpack does not fail if files are missing.

#### Local Configuration
Set `APPD_CONF_DIR` to a relative path which points to the directory in your application files where your custom configuration exists.

The Java buildpack will take the `app_root` + `APPD_CONF_DIR` directory and attempt to copy the followinig files from that directory:

- `logging/log4j2.xml`
- `logging/log4j.xml`
- `app-agent-config.xml`
- `controller-info.xml`
- `service-endpoint.xml`
- `transactions.xml`
- `custom-interceptors.xml`
- `custom-activity-correlation.xml`

Any files that exist will be copied to the configuration directory. The buildpack does not fail if files are missing.


[`config/app_dynamics_agent.yml`]: ../config/app_dynamics_agent.yml
[AppDynamics Java Agent Configuration Properties]: https://docs.appdynamics.com/display/PRO42/Java+Agent+Configuration+Properties
[AppDynamics Service]: http://www.appdynamics.com
[Configuration and Extension]: ../README.md#configuration-and-extension
[repositories]: extending-repositories.md
[this listing]: https://packages.appdynamics.com/java/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
