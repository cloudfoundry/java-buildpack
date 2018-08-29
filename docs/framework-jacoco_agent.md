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
| `address` | The host for the agent to connect to
| `excludes` | (Optional) A list of class names that should be excluded from execution analysis. The list entries are separated by a colon (:) and may use wildcard characters (* and ?).
| `includes` | (Optional) A list of class names that should be included in execution analysis. The list entries are separated by a colon (:) and may use wildcard characters (* and ?).
| `port` | (Optional) The port for the agent to connect to

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/jacoc_agent.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the JaCoCo repository index ([details][repositories]).
| `version` | The version of JaCoCo to use. Candidate versions can be found in [this listing][].

### Additional Resources
The framework can also be configured by overlaying a set of resources on the default distribution.  To do this, add files to the `resources/jacoco_agent` directory in the buildpack fork.  For example, to override the default `jacoco.yml` add your custom file to `resources/jacoco_agent/jacoco.yml`.

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/jacoco_agent.yml`]: ../config/jacoco_agent.yml
[JaCoCo Service]: http://www.jacoco.org/jacoco/
[repositories]: extending-repositories.md
[this listing]: https://java-buildpack.cloudfoundry.org/jacoco/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
