# Luna Security Provider Framework
The Luna Security Provider Framework causes an application to be automatically configured to work with a bound [Luna Security Service][]. **Note:** This framework is disabled by default.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a single bound Luna Security Provider service. The existence of an Luna Security service defined by the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service name, label or tag with <code>luna</code> as a substring.
</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>luna-security-provider=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
When binding to the Luna Security Provider using a user-provided service, it must have name or tag with `luna` in it. The credential payload can contain the following entries:

| Name | Description
| ---- | -----------
| `host` | The controller host name
| `host-certificate` | A PEM encoded host certificate
| `client-private-key` | A PEM encoded client private key
| `client-certificate` | A PEM encoded client certificate

To provide more complex values such as the PEM certificates, using the interactive mode when creating a user-provided service will manage the character escaping automatically.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/luna_security_provider.yml`][] file in the buildpack. The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Luna Security Provider repository index ([details][repositories]).
| `version` | Version of the Luna Security Provider to use.

### Additional Resources
The framework can also be configured by overlaying a set of resources on the default distribution.  To do this, add files to the `resources/luna_security_provider` directory in the buildpack fork.

[`config/luna_security_provider.yml`]: ../config/luna_security_provider.yml
[Luna Security Service]: http://www.safenet-inc.com/data-encryption/hardware-security-modules-hsms/
[Configuration and Extension]: ../README.md#configuration-and-extension
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
