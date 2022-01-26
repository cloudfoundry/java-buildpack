# Traceable Javaagent Framework
The [Traceable](https://traceable.ai) Javaagent Framework installs an agent that allows your application to be instrumented by the Traceable Java Tracing Agent. 

The framework will configure the JVM to use the Traceable Javagent, which can be configured using Java system properties or environment variables. Configuration options are documented [here](https://docs.traceable.ai/docs/java)

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>All must be true:
        <ul>
            <li><code>HT_REPORTING_ENDPOINT</code> or <code>-Dht.reporting.endpoint</code> defined and contain the HTTP endpoint of the Traceable Platform Agent endpoint for recieving traces</li>
            <li><code>TA_OPA_ENDPOINT</code> or <code>-Dta.opa.endpoint</code> defined and contain the HTTP endpoint of the Traceable Platform Agent endpoint for providing OPA policies</li>
        </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><code>traceable-javaagent=&lt;version&gt;</code></td>
  </tr>
</table>

Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].
The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

The javaagent can be configured directly via environment variables or system properties as defined in the [Configuration of Traceable Javaagent][https://docs.traceable.ai/docs/java] documentation.


| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Traceable Javaagent repository index ([details][repositories]).
| `version` | The Traceable Javaagent version to use. Candidate versions can be found in [this listing][https://downloads.traceable.ai/agent/java/cloudfoundry/index.yml].


[Configuration and Extension]: ../README.md#configuration-and-extension
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
