# Elastic APM Agent Framework

The Elastic APM Agent Framework causes an application to be automatically configured to work with [Elastic APM][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a single bound Elastic APM service. The existence of an Elastic APM service defined by the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service name, label or tag with <code>elastic-apm</code> as a substring.
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>elastic-apm-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
When binding Elastic APM using a user-provided service, it must have name or tag with `elasticapm` or `elastic-apm` in it. The credential payload can contain the following entries.

| Name | Description
| ---- | -----------
| `server_urls` | The URLs for the Elastic APM Server. They must be fully qualified, including protocol (http or https) and port.
| `secret_token` (Optional)| This string is used to ensure that only your agents can send data to your APM server. Both the agents and the APM server have to be configured with the same secret token. Use if APM Server requires a token.
| `***`	(Optional) | Any additional entries will be applied as a system property appended to `-Delastic.apm.` to allow full configuration of the agent. See [Configuration of Elastic Agent][]. Values are shell-escaped by default, but do have limited support, use with caution, for incorporating subshells (i.e. `$(some-cmd)`) and accessing environment variables (i.e. `${SOME_VAR}`).


### Creating an Elastic APM USer Provided Service
Users must provide their own Elastic APM service. A user-provided Elastic APM service must have a name or tag with `elastic-apm` in it so that the Elastic APM Agent Framework will automatically configure the application to work with the service.

Example of a minimal configuration:

```
cf cups my-elastic-apm-service -p '{"server_urls":"https://my-apm-server:8200","secret_token":"my-secret-token"}'
```

Example of a configuration with additional configuration parameters:

```
cf cups my-elastic-apm-service -p '{"server_urls":"https://my-apm-server:8200","secret_token":"","server_timeout":"10s","environment":"production"}'
```

Bind your application to the service using:

`cf bind-service my-app-name my-elastic-apm-service`

or use the `services` block in the application manifest file.


## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework has no user-configurable buildpack options.  The Elastic APM agent version is managed by the buildpack manifest.  Agent behaviour is configured entirely through the bound service credentials (see [User-Provided Service](#user-provided-service) above).


[Configuration and Extension]: ../README.md#configuration-and-extension
[Elastic APM]: https://www.elastic.co/guide/en/apm/agent/java/current/index.html
[Configuration of Elastic Agent]: https://www.elastic.co/guide/en/apm/agent/java/current/configuration.html
