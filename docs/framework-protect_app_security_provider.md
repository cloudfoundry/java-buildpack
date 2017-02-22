# ProtectApp Security Provider Framework
The ProtectApp Security Provider Framework causes an application to be automatically configured to work with a bound [ProtectApp Security Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a single bound ProtectApp Security Provider service. The existence of an ProtectApp Security service defined by the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service name, label or tag with <code>protectapp</code> as a substring.
</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>protect-app-security-provider=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
When binding to the ProtectApp Security Provider using a user-provided service, it must have name or tag with `protectapp` in it. The credential payload can contain the following entries:

| Name | Description
| ---- | -----------
| `client` | The client configuration
| `trusted_certificates` | An array of certs containing trust information
| `NAE_IP.1` | A list of KeySecure server ips or hostnames to be used
| `***` | (Optional) Any additional entries will be applied as a system property appended to `-Dcom.ingrian.security.nae.` to allow full configuration of the library.

#### Client Configuration
| Name | Description
| ---- | -----------
| `certificate` | A PEM encoded client certificate
| `private_key` | A PEM encoded client private key

#### Trusted Certs Configuration
One or more PEM encoded certificate

### Example Credentials Payload
```
{
  "client": {
    "certificate": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
    "private_key": "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
  },
  "trusted_certificates": [
    "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
    "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"
  ],
  "NAE_IP.1": "192.168.1.25:192.168.1.26"
}
```

### Creating Credential Payload
In order to create the credentials payload, you should collapse the JSON payload to a single line and set it like the following

```
$ cf create-user-provided-service protectapp -p '{"client":{"certificate":"-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----","private_key":"-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"},"trusted_certificates":["-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----","-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"],"NAE_IP.1":"192.168.1.25:192.168.1.26"}'
```

You may want to use a file for this

Note the client portion is very exacting and needs line breaks in the body every 64 characters.

1. The file must contain:
`-----BEGIN CERTIFICATE-----`
on a separate line (i.e. it must be terminated with a newline).
1. Each line of "gibberish" must be 64 characters wide.
1. The file must end with:
`-----END CERTIFICATE-----`
and also be terminated with a newline.
1. Don't save the cert text with Word. It must be in ASCII.
1. Don't mix DOS and UNIX style line terminations.

So, here are a few steps you can take to normalize your certificate:

1. Run it through `dos2unix`
`$ dos2unix cert.pem`
1. Run it through `fold`
`$ fold -w 64 cert.pem`

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/protect_app_security_provider.yml`][] file in the buildpack. The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the ProtectApp Security Provider repository index ([details][repositories]).
| `version` | Version of the ProtectApp Security Provider to use.

### Additional Resources
The framework can also be configured by overlaying a set of resources on the default distribution.  To do this, add files to the `resources/protect_app_security_provider` directory in the buildpack fork.

[`config/protect_app_security_provider.yml`]: ../config/protect_app_security_provider.yml
[ProtectApp Security Service]: https://safenet.gemalto.com/data-encryption/protectapp-application-protection/
[Configuration and Extension]: ../README.md#configuration-and-extension
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
