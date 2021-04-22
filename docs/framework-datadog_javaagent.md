# Datadog APM Javaagent Framework
The [Datadog APM]() Javaagent Framework allows your application to be dynamically instrumented [by][datadog-javaagent] `dd-java-agent.jar`.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>One of the following environment variables configured:
      <ul>
        <li><code>DD_APM_ENABLED</code> configured as <code>true</code></li>
        <li><code>DD_API_KEY</code> defined with the assumption of a <a href='https://github.com/DataDog/datadog-cloudfoundry-buildpack'>datadog-cloudfoundry-buildpack</a> configured, and <code>DD_APM_ENABLED</code> not <code>false</code></li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>datadog-javaagent=&lt;version&gt;</tt></td>
  </tr>
</table>

Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].
The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

The javaagent can be configured directly via environment variables or system properties as defined in the [Configuration of Datadog Javaagent][] documentation.


| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Datadog Javaagent repository index ([details][repositories]).
| `version` | The `dd-java-agent` version to use. Candidate versions can be found in [this listing][].


[Configuration and Extension]: ../README.md#configuration-and-extension
[Datadog APM]: https://www.datadoghq.com/product/apm/
[datadog-javaagent]: https://github.com/datadog/dd-trace-java
[Configuration of Datadog Javaagent]: https://docs.datadoghq.com/tracing/setup_overview/setup/java/#configuration
[this listing]: https://raw.githubusercontent.com/datadog/dd-trace-java/cloudfoundry/index.yml
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
