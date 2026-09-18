# Container Security Provider
The Container Security Provider Framework adds a Security Provider to the JVM that automatically includes BOSH trusted certificates and Diego identity certificates and private keys.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Unconditional</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>container-security-provider=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by setting the `JBP_CONFIG_CONTAINER_SECURITY_PROVIDER` environment variable.  The value must be valid inline YAML.

| Name | Description
| ---- | -----------
| `key_manager_enabled` | Whether the container `KeyManager` is enabled.  Defaults to `true`.
| `trust_manager_enabled` | Whether the container `TrustManager` is enabled.  Defaults to `true`.

### Examples

Disable the `KeyManager`:

```yaml
JBP_CONFIG_CONTAINER_SECURITY_PROVIDER: '{key_manager_enabled: false}'
```

Disable the `TrustManager`:

```yaml
JBP_CONFIG_CONTAINER_SECURITY_PROVIDER: '{trust_manager_enabled: false}'
```

## Security Provider
The [security provider][] added by this framework contributes two types, a `TrustManagerFactory` and a `KeyManagerFactory`.  The `TrustManagerFactory` adds an additional new `TrustManager` after the configured system `TrustManager` which reads the contents of `/etc/ssl/certs/ca-certificates.crt` which is where [BOSH trusted certificates][] are placed.  The `KeyManagerFactory` adds an additional `KeyManager` after the configured system `KeyManager` which reads the contents of the files specified by `$CF_INSTANCE_CERT` and `$CF_INSTANCE_KEY` which are set by Diego to give each container a unique cryptographic identity.  These `TrustManager`s and `KeyManager`s are used transparently by any networking library that reads standard system SSL configuration and can be used to enable system-wide trust and [mutual TLS authentication][].


[BOSH trusted certificates]: https://bosh.io/docs/trusted-certs.html
[Configuration and Extension]: ../README.md#configuration-and-extension
[mutual TLS authentication]: https://en.wikipedia.org/wiki/Mutual_authentication
[security provider]: https://github.com/cloudfoundry/java-buildpack-security-provider
