# CA Introscope APM Framework
The CA Introscope APM Framework causes an application to be automatically configured to work with a bound [Introscope service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound Introscope service.
      <ul>
        <li>Existence of a Introscope service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>introscope</code> as a substring.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>introscope-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service (Optional)
Users may optionally provide their own Introscope service. A user-provided Introscope service must have a name or tag with `introscope` in it so that the Introscope Agent Framework will automatically configure the application to work with the service.

The credential payload of the service may contain the following entries:

| Name | Description
| ---- | -----------
| `agent-name` | (Optional) The name that should be given to this instance of the Introscope agent
| `url` | The url of the Introscope Enterprise Manager server


To provide more complex values such as the `agent-name`, using the interactive mode when creating a user-provided service will manage the character escaping automatically. For example, the default `agent-name` could be set with a value of `agent-$(expr "$VCAP_APPLICATION" : '.*application_name[": ]*\([[:word:]]*\).*')` to calculate a value from the Cloud Foundry application name.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/introscope_agent.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Introscope Agent repository index ([details][repositories]).
| `version` | The version of Introscope Agent to use.

### Additional Resources
The framework can also be configured by overlaying a set of resources on the default distribution.  To do this, add files to the `resources/ca_wily_agent` directory in the buildpack fork.  For example, to override the default profile add your custom profile to `resources/introscope_agent/`.

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/intoscope_agent.yml`]: ../config/intoscope_agent.yml
[Introscope service]: http://www.ca.com/us/opscenter/ca-application-performance-management.aspx
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
