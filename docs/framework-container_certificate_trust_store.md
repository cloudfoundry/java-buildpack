# Container Certificate Trust Store Framework
The Container Certificate Trust Store Framework contributes a Java `KeyStore` containing the certificates trusted by the operating system in the container to the application at rutime.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a <tt>/etc/ssl/certs/ca-certificates.crt</tt> file and <tt>enabled</tt> set in the <tt>config/container_certificate_trust_store.yml</tt> file</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>container-certificate-trust-store=&lt;number-of-certificates&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by creating or modifying the [`config/container_certificate_trust_store.yml`][] file in the buildpack fork.

| Name | Description
| ---- | -----------
| `enabled` | Whether to enable the trust store

[`config/container_certificate_trust_store.yml`]: ../config/container_certificate_trust_store.yml
[Configuration and Extension]: ../README.md#configuration-and-extension
