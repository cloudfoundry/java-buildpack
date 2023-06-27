# OpenTelemetry Javaagent

The OpenTelemetry Javaagent buildpack framework will cause an application to be automatically instrumented
with the [OpenTelemetry Javaagent Instrumentation](https://github.com/open-telemetry/opentelemetry-java-instrumentation).

Data will be sent directly to the OpenTelemetry Collector. 

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a bound service containing the string <code>otel-collector</code></td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><code>opentelemetry-javaagent=&lt;version&gt;</code></td>
  </tr>
</table>

Tags are printed to standard output by the buildpack detect script

## User-Provided Service

Users are currently expected to provide their own "custom user provided service" (cups) 
instance and bind it to their application. The service MUST contain the string `otel-collector`.

### Choosing a version

Most users should skip this and simply use the latest version of the agent available (the default).
To override the default and choose a specific version, you can use the `JBP_CONFIG_*` mechanism
and set the `JBP_CONFIG_OPENTELEMETRY_JAVAAGENT` environment variable for your application.

For example, to use version 1.27.0 of the OpenTelemetry Javaagent Instrumentation, you
could run:
```
$ cf set-env testapp JBP_CONFIG_OPENTELEMETRY_JAVAAGENT '{version: 1.27.0}'
```
 
# Additional Resources

* [OpenTelemetry Javaagent Instrumentation](https://github.com/open-telemetry/opentelemetry-java-instrumentation) on GitHub
