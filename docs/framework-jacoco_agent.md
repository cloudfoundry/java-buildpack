# JaCoco Agent Framework
The JaCoCo Agent Framework causes an application to be automatically configured to work with a bound [JaCoCo Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound JaCoCo service.
      <ul>
        <li>Existence of a JaCoCo service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>jacoco</code> as a substring.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>jacoco-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service (Optional)
Users may optionally provide their own JaCoCo service. A user-provided JaCoCo service must have a name or tag with `jacoco` in it so that the JaCoCo Agent Framework will automatically configure the application to work with the service.

The credential payload of the service may contain the following entries:

| Name | Description
| ---- | -----------
| `address` | The host for the agent to connect to or listen on
| `excludes` | (Optional) A list of class names that should be excluded from execution analysis. The list entries are separated by a colon (:) and may use wildcard characters (* and ?).
| `includes` | (Optional) A list of class names that should be included in execution analysis. The list entries are separated by a colon (:) and may use wildcard characters (* and ?).
| `port` | (Optional) The port for the agent to connect to or listen on
| `output` | (Optional) The mode for the agent. Possible values are either tcpclient (default) or tcpserver. 

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework has no user-configurable buildpack options.  The JaCoCo agent version is managed by the buildpack manifest.  Agent properties are configured through the bound service credentials (see [User-Provided Service](#user-provided-service-optional) above).

### Additional Resources

**Note:** The `resources/jacoco_agent` directory approach from the Ruby buildpack (2013-2025) is no longer supported. This was a **buildpack-level** feature where teams would fork the java-buildpack repository, add custom files to `resources/jacoco_agent/`, and package their custom buildpack. The Go buildpack does not package the `resources/` directory.

[Configuration and Extension]: ../README.md#configuration-and-extension
[JaCoCo Service]: http://www.jacoco.org/jacoco/
