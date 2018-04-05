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

The framework can be configured by modifying the [`config/container_security_provider.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Container Customizer repository index ([details][repositories]).
| `version` | The version of Container Customizer to use. Candidate versions can be found in [this listing][].
| `key_manager_enabled` | Whether the container `KeyManager` is enabled.  Defaults to `true`.
| `trust_manager_enabled` | Whether the container `TrustManager` is enabled.  Defaults to `true`.

## Security Provider
The [security provider][] added by this framework contributes two types, a `TrustManagerFactory` and a `KeyManagerFactory`.  The `TrustManagerFactory` adds an additional new `TrustManager` after the configured system `TrustManager` which reads the contents of `/etc/ssl/certs/ca-certificates.crt` which is where [BOSH trusted certificates][] are placed.  The `KeyManagerFactory` adds an additional `KeyManager` after the configured system `KeyManager` which reads the contents of the files specified by `$CF_INSTANCE_CERT` and `$CF_INSTANCE_KEY` which are set by Diego to give each container a unique cryptographic identity.  These `TrustManager`s and `KeyManager`s are used transparently by any networking library that reads standard system SSL configuration and can be used to enable system-wide trust and [mutual TLS authentication][].


[`config/container_security_provider.yml`]: ../config/container_security_provider.yml
[BOSH trusted certificates]: https://bosh.io/docs/trusted-certs.html
[Configuration and Extension]: ../README.md#configuration-and-extension
[mutual TLS authentication]: https://en.wikipedia.org/wiki/Mutual_authentication
[repositories]: extending-repositories.md
[security provider]: https://github.com/cloudfoundry/java-buildpack-security-provider
[this listing]: http://download.pivotal.io.s3.amazonaws.com/container-security-provider/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
