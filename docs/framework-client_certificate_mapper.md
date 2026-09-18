# Client Certificate Mapper
The Client Certificate Mapper Framework adds a Servlet Filter to applications that will that maps the `X-Forwarded-Client-Cert` to the `javax|jakarta.servlet.request.X509Certificate` Servlet attribute.

The Client Certificate Mapper Framework will download a helper library, [java-buildpack-client-certificate-mapper][library repository], that will enrich Spring Boot (2 and 3), as well as JEE / JakartaEE applications classpath with a servlet filter.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Unconditional</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>client-certificate-mapper=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by setting the `JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER` environment variable.  The value must be valid inline YAML.

| Name              | Description
|-------------------| -----------
| `enabled` | Whether to enable the Client Certificate Mapper.  Defaults to `true`.

### Example

Disable the client certificate mapper:

```yaml
JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER: '{enabled: false}'
```

## Servlet Filter
The [Servlet Filter][] added by this framework maps the `X-Forwarded-Client-Cert` to the `javax.servlet.request.X509Certificate` Servlet attribute for each request.  The `X-Forwarded-Client-Cert` header is contributed by the Cloud Foundry Router and contains the any TLS certificate presented by a client for mututal TLS authentication.  This certificate can then be used by any standard Java security framework to establish authentication and authorization for a request.

[Configuration and Extension]: ../README.md#configuration-and-extension
[Servlet Filter]: https://github.com/cloudfoundry/java-buildpack-client-certificate-mapper
[library repository]: https://github.com:cloudfoundry/java-buildpack-client-certificate-mapper.git
