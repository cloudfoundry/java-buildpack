# Jaeger Agent Framework
The Jaeger Agent coprocess causes an application to be automatically configured to work with a bound [Jaeger Service][].  **Note:** This framework is disabled by default.

The agent authenticates itself with the collector using mTLS and forwards traces to the collector configured to it.


A sample user provided service is shown below:

```
{
	"jaeger-collector-url": "jaeger-collector-url.com:443",
	"tls_ca":"-----BEGIN CERTIFICATE-----\nMIID3D...def+7/Y\n-----END CERTIFICATE-----",
	"tls_cert":"-----BEGIN CERTIFICATE-----\nMIID3D...abcd+7/Y\n-----END CERTIFICATE-----",
	"tls_key": "-----BEGIN PRIVATE KEY-----\nMIIEv............7/Y\n-----END PRIVATE KEY-----"

}

```
The agent is enabled when the user-service is provided.

## User-Provided Service
 When binding Jaeger Service using a user-provided service, it must have name or tag with `jaeger` in it. The credential payload must contain the following entries. 

| Name | Description
| ---- | -----------
| `jaeger-collector-url` | The remote server url of the Jaeger Collector.
| `tls_ca` | TLS CA (Certification Authority) string used to verify the remote server .
| `tls_cert` | TLS Certificate string, used to identify this agent to the remote server.
| `tls_key` | TLS Private Key string, used to identify this agent to the remote server.


To provide additional parameters ` JAEGER_ADDITIONAL_ARGUEMENTS` is added to the enviornment.

E.g. 
```
JAEGER_ADDITIONAL_ARGUEMENTS: --agent.tags=key=value --processor.jaeger-compact.workers=5
```

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/jaeger_agent.yml`][] file in the buildpack fork.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Jaeger binary download.
| `version` | The version of jaeger-agent to use. Candidate versions can be found in [this listing][].


[`config/jaeger_agent.yml`]: ../config/jaeger_agent.yml
[Jaeger Service]: https://www.jaegertracing.io
[Configuration and Extension]: ../README.md#configuration-and-extension
[this listing]: https://github.com/jaegertracing/jaeger/tags
