# Datadog APM Javaagent Framework
The [Datadog APM]() Javaagent Framework installs an agent that allows your application to be dynamically instrumented [by][datadog-javaagent] `dd-java-agent.jar`. 

For this functionality to work, you **must** also use this feature in combination with the [Datadog Cloudfoundry Buildpack](). The Datadog Cloudfoundry Buildpack **must** run first, so that it can supply the components to which the Datadog APM agent will talk. Please make sure you follow the instructions on the README for the Datadog Cloudfoundry Buildpack to enable and configure it.

The framework will configure the Datadog agent for correct use in most situations, however you may adjust its behavior by setting additional environment variables. For a complete list of Datadog Agent configuration options, please see the [Datadog Documentation](https://docs.datadoghq.com/tracing/setup_overview/setup/java/?tab=containers#configuration).

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>All must be true:
        <ul>
            <li>The Datadog Buildpack must be included</li>
            <li><code>DD_API_KEY</code> defined and contain your API key</li>
        </ul>
        Optionally, you may set <code>DD_APM_ENABLED</code> to <code>false</code> to force the framework to not contribute the agent.
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><code>datadog-javaagent=&lt;version&gt;</code></td>
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
[Datadog Cloudfoundry Builpack]: https://github.com/DataDog/datadog-cloudfoundry-buildpack
[datadog-javaagent]: https://github.com/datadog/dd-trace-java
[Configuration of Datadog Javaagent]: https://docs.datadoghq.com/tracing/setup_overview/setup/java/#configuration
[this listing]: https://raw.githubusercontent.com/datadog/dd-trace-java/cloudfoundry/index.yml
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
