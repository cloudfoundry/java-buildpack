# New Relic Agent Framework
The New Relic Agent Framework causes an application to be automatically configured to work with a bound [New Relic Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound New Relic service.
      <ul>
        <li>Existence of a New Relic service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>newrelic</code> as a substring.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>new-relic-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service (Optional)
Users may optionally provide their own New Relic service. A user-provided New Relic service must have a name or tag with `newrelic` in it so that the New Relic Agent Framework will automatically configure the application to work with the service.

The credential payload of the service may contain the following entries:

| Name | Description
| ---- | -----------
| `license_key` | (Optional) Either this credential or `licenseKey` must be provided. If both are provided then the value for `license_key` will always win. The license key to use when authenticating.
| `licenseKey` | (Optional) As above.
| `***` | (Optional) Any additional entries will be applied as a system property appended to `-Dnewrelic.config.` to allow full configuration of the agent.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/new_relic_agent.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the New Relic repository index ([details][repositories]).
| `version` | The version of New Relic to use. Candidate versions can be found in [this listing][].
| `extensions.repository_root` | The URL of the Extensions repository index ([details][repositories]).
| `extensions.version` | The version of the Extensions to use. Candidate versions can be found in the the repository that you have created to house the Extensions.

### Extensions

Custom New Relic instrumentation in the form of [Extension XML Files][] (or JARs) may be provided via a custom repository.

Example in a manifest.yml

```yaml
env:
  JBP_CONFIG_NEW_RELIC_AGENT: '{ extensions: { repository_root: "http://repository..." } }'
```

The artifacts that the repository provides must be in TAR format and must include the extension files in a directory, with a structure like:

```
extensions
|- my-extension.xml
|- my-other-extension.jar
|...
```

### Additional Resources
The framework can also be configured by overlaying a set of resources on the default distribution.  To do this, add files to the `resources/new_relic_agent` directory in the buildpack fork.  For example, to override the default `new_relic.yml` add your custom file to `resources/new_relic_agent/newrelic.yml`.

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/new_relic_agent.yml`]: ../config/new_relic_agent.yml
[New Relic Service]: https://newrelic.com
[repositories]: extending-repositories.md
[this listing]: https://download.run.pivotal.io/new-relic/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
[Extension XML Files]: https://docs.newrelic.com/docs/agents/java-agent/custom-instrumentation/java-instrumentation-xml
