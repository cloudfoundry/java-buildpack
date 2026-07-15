# Elastic OTel Java Agent Framework

The Elastic OTel Java Agent Framework causes an application to be automatically configured to work with the [Elastic Distribution of OpenTelemetry Java][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a bound Elastic OTel service. The service must have a name, label, or tag containing <code>elastic-otel</code>, <code>edot-java</code>, or <code>elastic-edot</code>, and must provide an OTLP endpoint plus authentication credentials. The framework can also be enabled explicitly with <code>ELASTIC_OTEL_AGENT</code>.</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>elastic-otel-javaagent=&lt;version&gt;</tt></td>
  </tr>
</table>

Tags are printed to standard output by the buildpack detect script.

## User-Provided Service

Users can provide their own Elastic OTel service. A user-provided service must have a name or tag with `elastic-otel`, `edot-java`, or `elastic-edot` in it so that the framework configures the application with the EDOT Java agent.

The credential payload can contain the following entries.

| Name | Description |
| ---- | ----------- |
| `otel.exporter.otlp.endpoint` | The OTLP endpoint for your Elastic deployment or EDOT Collector. Aliases: `otlp_endpoint`, `otlpEndpoint`, `endpoint`. |
| `otel.exporter.otlp.headers` | Explicit OTLP headers, for example `Authorization=ApiKey <key>`. If present, this takes precedence over derived authentication headers. |
| `api_key` | Elastic API key. Converted to `otel.exporter.otlp.headers=Authorization=ApiKey <key>`. |
| `secret_token` | Bearer token. Converted to `otel.exporter.otlp.headers=Authorization=Bearer <token>`. |
| `access_token` | Bearer token. Converted to `otel.exporter.otlp.headers=Authorization=Bearer <token>`. |
| `otel.*` | Any additional OpenTelemetry configuration applied as JVM system properties. |
| `elastic.otel.*` | Any additional Elastic OTel configuration applied as JVM system properties. |

### Creating an Elastic OTel User-Provided Service

Example minimal configuration:

```
cf cups my-elastic-otel-service -p '{"otel.exporter.otlp.endpoint":"https://my-deployment.ingest.us-west1.gcp.cloud.es.io","api_key":"my-api-key"}'
```

Example configuration with explicit OTLP headers and resource attributes:

```
cf cups my-elastic-otel-service -p '{"otel.exporter.otlp.endpoint":"https://my-deployment.ingest.us-west1.gcp.cloud.es.io","otel.exporter.otlp.headers":"Authorization=ApiKey my-api-key","otel.resource.attributes":"deployment.environment.name=production"}'
```

Bind your application to the service using:

`cf bind-service my-app-name my-elastic-otel-service`

or use the `services` block in the application manifest file.

## Configuration

For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework uses the dependency version configured in `manifest.yml`.

| Name | Description |
| ---- | ----------- |
| `version` | The version of Elastic OTel Java agent to use. The current buildpack manifest uses the `elastic-otel-javaagent` dependency. |

The framework sets `otel.service.name` from `VCAP_APPLICATION.application_name` if it is not configured in service credentials or `OTEL_SERVICE_NAME`. It also sets `deployment.environment.name` from `VCAP_APPLICATION.space_name` when `otel.resource.attributes` is not configured.

> **Warning**
> Do not bind this framework alongside the Elastic APM Agent, OpenTelemetry Javaagent, Splunk OTel Java Agent, or another Java agent framework for the same application. Running multiple Java agents in the same JVM can cause duplicate telemetry or conflicting instrumentation.

## Migration From Elastic APM Agent

The Elastic OTel Java agent uses OTLP configuration. It does not use Elastic APM agent settings such as `server_url` or `secret_token` with the `elastic.apm.*` prefix.

When migrating, create a new service binding named or tagged for Elastic OTel and provide an OTLP endpoint plus `otel.exporter.otlp.headers` or `api_key`.

[Configuration and Extension]: ../README.md#configuration-and-extension
[Elastic Distribution of OpenTelemetry Java]: https://www.elastic.co/docs/reference/opentelemetry/edot-sdks/java
