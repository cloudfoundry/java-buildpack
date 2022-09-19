# Splunk Distribution of OpenTelemetry Java Instrumentation

The Splunk OpenTelemetry Java Agent buildpack framework will cause an application to be automatically instrumented
with the [Splunk distribution of OpenTelemetry Java Instrumentation](https://github.com/signalfx/splunk-otel-java).

Trace data will be sent directly to Splunk Observability Cloud. 

* **Detection criteria**: Existence of a bound service with the name `splunk-o11y`.
* **Tags**: `splunk-otel-java-agent=<version>` to control which version of the instrumentation agent is used. 
  * Default = latest available version

## User-Provided Service

Users are currently expected to provide their own "custom user provided service" (cups) 
instance and bind it to their application. The service MUST be named `splunk-o11y`.

For example, to create a service named `splunk-o11y` that represents Observability Cloud 
realm `us0` and represents a user environment named `cf-demo`, you could use the following
commands:

```
$ cf cups splunk-o11y -p \
   '{"splunk.realm": "us0", "splunk.access.token": "<redacted>", "otel.resource.attributes": "deployment.environment=cf-demo"}'
$ cf bind-service myApp splunk-o11y
$ cf restage myApp
```

The `credential` field of the service should provide these entries:

| Name                   | Required? | Description
|------------------------|-----------| -----------
| `splunk.access.token`  | Yes       | The Splunk [org access token](https://docs.splunk.com/observability/admin/authentication-tokens/org-tokens.html).
| `splunk.realm`         | Yes       | The Splunk realm where data will be sent. This is commonly `us0` or `eu0` etc.
| `otel.*` or `splunk.*` | Optional  | All additional credentials starting with these prefixes will be appended to the application's JVM arguments as system properties.

### Choosing a version

Most users should skip this and simply use the latest version of the agent available (the default).
To override the default and choose a specific version, you can use the `JBP_CONFIG_*` mechanism
and set the `JBP_CONFIG_SPLUNK_OTEL_JAVA_AGENT` environment variable for your application.

For example, to use version 1.16.0 of the Splunk OpenTelemetry Java Instrumentation, you
could run:
```
$ cf set-env testapp JBP_CONFIG_SPLUNK_OTEL_JAVA_AGENT '{version: 1.16.0}'
```
 
# Additional Resources

* [Splunk Observability](https://www.splunk.com/en_us/products/observability.html)
* [Splunk Distribution of OpenTelemetry Java](https://github.com/signalfx/splunk-otel-java) on GitHub
