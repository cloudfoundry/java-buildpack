# Dyadic EKM Security Provider Framework
The Dyadic EKM Security Provider Framework causes an application to be automatically configured to work with a bound [Dyadic EKM][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a single bound Dyadic EKM Security Provider service. The existence of an Dyadic EKM Security service defined by the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service name, label or tag with <code>dyadic</code> as a substring.
</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>dyadic-security-provider=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
When binding to the Dyadic EKM Security Provider using a user-provided service, it must have name or tag with `dyadic` in it. The credential payload can contain the following entries:

| Name | Description
| ---- | -----------
| `ca` | A PEM encoded CA certificate
| `key` | A PEM encoded client private key
| `recv_timeout` | A timeout for receiving data (in milliseconds)
| `retries` | The number of times to retry the connection
| `send_timeout` | A timeout for sending data (in milliseconds)
| `servers` | A comma delimited list of servers to connect to

### Example Credentials Payload
```
{
  "ca": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
  "key": "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----",
  "recv_timeout": 1000,
  "retries": 5,
  "send_timeout": 1000,
  "servers": "test-server-1,test-server-2"
}
```

### Creating Credential Payload
In order to create the credentials payload, you should collapse the JSON payload to a single line and set it like the following

```
$ cf create-user-provided-service dyadic -p '{"ca":"-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----","key":"-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----","recv_timeout":1000,"retries":5,"send_timeout":1000,"servers":"test-server-1,test-server-2"}'
```

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/dyadic_security_provider.yml`][] file in the buildpack. The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Dyadic Security Provider repository index ([details][repositories]).
| `version` | Version of the Dyadic Security Provider to use.

### Additional Resources
The framework can also be configured by overlaying a set of resources on the default distribution.  To do this, add files to the `resources/dyadic_security_provider` directory in the buildpack fork.

[`config/dyadic_security_provider.yml`]: ../config/dyadic_ekm_security_provider.yml
[Dyadic EKM]: https://www.dyadicsec.com/key_management/
[Configuration and Extension]: ../README.md#configuration-and-extension
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
