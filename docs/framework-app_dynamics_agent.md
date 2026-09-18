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

The framework has no user-configurable options.  The AppDynamics agent version is managed by the buildpack manifest.  See [Additional Resources](#additional-resources) below for application-level configuration options.

### Additional Resources
The framework can be configured by providing custom configuration files.

#### Default Configuration
The buildpack includes a default `app-agent-config.xml` configuration file that is embedded at compile time. This default configuration provides sensible defaults for Cloud Foundry deployments, including sensitive data filtering for passwords and keys.

The default configuration file is located in `src/java/resources/files/app_dynamics_agent/defaults/conf/app-agent-config.xml`.

##### Customizing Default Configuration via Fork
To customize the default AppDynamics configuration across all applications using your buildpack:

1. Fork the java-buildpack repository
2. Modify the configuration file in `src/java/resources/files/app_dynamics_agent/defaults/conf/`
3. Build and package your custom buildpack
4. Upload the custom buildpack to your Cloud Foundry foundation

This approach is useful for operators who want to enforce organization-wide AppDynamics settings.

Configuration files are applied in this order:

1. Default AppDynamics configuration (embedded in buildpack)
2. External Configuration (if configured via `APPD_CONF_HTTP_URL`)
3. Local Configuration (if configured via `APPD_CONF_DIR`)

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


[AppDynamics Java Agent Configuration Properties]: https://docs.appdynamics.com/display/PRO42/Java+Agent+Configuration+Properties
[AppDynamics Service]: http://www.appdynamics.com
[Configuration and Extension]: ../README.md#configuration-and-extension
