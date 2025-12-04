# CF Metrics Exporter

The CF Metrics Exporter adds the cf-metrics-exporter Java agent to your application so it can export Cloud Foundry runtime metrics. It parses the autoscaler endpoint from VCAP_SERVICES, calculates Requests Per Second (RPS), and emits the metric `custom_throughput` with unit `rps` (1/s).

Source and releases: https://github.com/rabobank/cf-metrics-exporter

Version used by default: 0.7.1

What it does
- Parse autoscaler endpoint info from VCAP_SERVICES.
- Collect RPS (Requests Per Second) from the application.
- Send RPS to the Cloud Foundry custom metrics endpoint as `custom_throughput` (unit: rps/1s).
- Average is computed over the configured interval (default 10s); longer intervals smooth peaks.

Supported RPS sources (rspType)
- spring-request (default): Uses byte code transformation to instrument Spring Boot request handling.
  - Transforms:
    - org.springframework.web.servlet.DispatcherServlet#doService 
    - org.springframework.web.reactive.DispatcherHandler#handle
  - Works with Netty (WebFlux/Reactor), Tomcat (also with virtual threads), Undertow.
- tomcat-mbean: Uses JMX MBean attribute `requestCount` on `Tomcat:type=GlobalRequestProcessor,name="http-nio-<port>"`. Requires `server.tomcat.mbeanregistry.enabled=true` in the application.
- random: Random RPS generator for testing.

Metric emitters
- CustomMetricsSender: Sends to the CF custom metrics endpoint (enabled when auto-scaler endpoint is found in VCAP_SERVICES).
- OtlpRpsExporter: Sends to an OTLP endpoint (enabled when an OTLP metrics endpoint is configured via environment, see below).
- LogEmitter: Logs metrics to stdout (enabled via the `enableLogEmitter` setting).

Enable via manifest (or environment)

env:
  CF_METRICS_EXPORTER_ENABLED: "true"

Agent settings
The agent understands both key=value options and flag-style options without a value. The buildpack passes options verbatim to the agent.

- debug: Enable debug logging. Flag only (no value needed): `debug`.
- trace: Enable trace logging. Flag only: `trace`.
- rpsType: Select RPS source. One of `spring-request` (default), `tomcat-mbean`, `random`.
- intervalSeconds: Interval in seconds for sampling and sending metrics. Default 10.
- metricsEndpoint: Explicit custom metrics endpoint (normally auto-detected from VCAP_SERVICES; not required).
- environmentVarName: Name of the env var to read to set the `environment` attribute (e.g. `CF_ENVIRONMENT`, when your app has `CF_ENVIRONMENT=test`).
- enableLogEmitter: Enable logging of emitted metrics. Flag only: `enableLogEmitter`.
- disableAgent: Disable the agent completely. Flag only: `disableAgent`.

Examples
1) Minimal with Spring Boot (default rspType) and log emitter enabled using flags (no equals):

env:
  CF_METRICS_EXPORTER_ENABLED: "true"
  CF_METRICS_EXPORTER_PROPS: "debug,enableLogEmitter"

2) Explicit rspType and interval using key=value, plus a flag without value:

env:
  CF_METRICS_EXPORTER_ENABLED: "true"
  CF_METRICS_EXPORTER_PROPS: "rpsType=tomcat-mbean,intervalSeconds=5,enableLogEmitter"

Notes on supplying options
- CF_METRICS_EXPORTER_PROPS is a raw string appended after `=` in the `-javaagent` option. You can copy/paste it to and from a plain Java command line.
- So use a comma-separated list to avoid issues with shell/argument parsing. Examples:
  - `debug,enableLogEmitter`
  - `rpsType=tomcat-mbean,intervalSeconds=5,enableLogEmitter`

OpenTelemetry export (optional)
- The agent will export `custom_throughput` to an OpenTelemetry collector when an OTLP endpoint is configured. Supported environment variables:
  - OTEL_EXPORTER_OTLP_ENDPOINT (preferred): e.g. `https://otel-collector.example.com`
  - MANAGEMENT_OTLP_METRICS_EXPORT_URL (alternative used by some setups)
- Protocol: http only; no authentication yet.
- Attributes on the metric: cf_application_name, cf_space_name, cf_organization_name, cf_instance_index, environment (from `environmentVarName`).

Cloud Foundry environment variables used
- VCAP_APPLICATION
- VCAP_SERVICES (should contain the custom metrics endpoint with basic auth or mTLS)
- CF_INSTANCE_INDEX

Troubleshooting
- Run with `debug` to see stack traces and diagnostic logging.
- For Tomcat MBean based RPS: ensure `server.tomcat.mbeanregistry.enabled=true` in application configuration.

Overriding artifact location/version (operators or advanced users)
- The buildpack reads `config/cf_metrics_exporter.yml` which defines `version` and `uri`.
- You can override via `JBP_CONFIG_CF_METRICS_EXPORTER`, for example:

cf set-env my-app JBP_CONFIG_CF_METRICS_EXPORTER '{ version: 0.7.1, uri: "https://github.com/rabobank/cf-metrics-exporter/releases/download/0.7.1/cf-metrics-exporter-0.7.1.jar" }'
