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

The credential payload of the service may contain any valid CA APM Java agent property.

The table below displays a subset of properties that are accepted by the buildpack.
Please refer to CA APM docs for a full list of valid agent properties.


| Name | Description
| ---- | -----------
|`agent_manager_credential`| (Optional) The credential that is used to connect to the Enterprise Manager server.
|`agentManager_url_1` | The url of the Enterprise Manager server.
|`agent_manager_url`| (Deprecated) The url of the Enterprise Manager server.
|`credential`| (Deprecated) The credential that is used to connect to the Enterprise Manager server


To provide more complex values such as the `agent_name`, using the interactive mode when creating a user-provided service will manage the character escaping automatically. For example, the default `agent_name` could be set with a value of `agent-$(expr "$VCAP_APPLICATION" : '.*application_name[": ]*\([[:word:]]*\).*')` to calculate a value from the Cloud Foundry application name.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework has no user-configurable buildpack options.  The Introscope agent version is managed by the buildpack manifest.  Agent properties are configured through the bound service credentials (see [User-Provided Service](#user-provided-service-optional) above).

### Additional Resources

**Note:** The `resources/introscope_agent` directory approach from the Ruby buildpack (2013-2025) is no longer supported. This was a **buildpack-level** feature where teams would fork the java-buildpack repository, add custom files to `resources/introscope_agent/`, and package their custom buildpack. The Go buildpack does not package the `resources/` directory.

[Configuration and Extension]: ../README.md#configuration-and-extension
[Introscope service]: http://www.ca.com/us/opscenter/ca-application-performance-management.aspx
