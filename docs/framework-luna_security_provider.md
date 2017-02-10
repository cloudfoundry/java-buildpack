# Luna Security Provider Framework
The Luna Security Provider Framework causes an application to be automatically configured to work with a bound [Luna Security Service][].

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
| `client` | A hash containing client configuration
| `servers` | An array of hashes containing server configuration
| `groups` | An array of hashes containing group configuration

#### Client Configuration
| Name | Description
| ---- | -----------
| `certificate` | A PEM encoded client certificate
| `private-key` | A PEM encoded client private key

#### Server Configuration
| Name | Description
| ---- | -----------
| `certificate` | A PEM encoded server certificate
| `name` | A host name or address

#### Group Configuration
| Name | Description
| ---- | -----------
| `label` | The label for the group
| `members` | An array of group member serial numbers

### Example Credentials Payload
```
{
  "client": {
    "certificate": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
    "private-key": "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
  },
  "servers": [
    {
      "name": "test-host-1",
      "certificate": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"
    },
    {
      "name": "test-host-2",
      "certificate": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"
    }
  ],
  "groups": [
    {
      "label": "test-group-1",
      "members": [
        "test-serial-number-1",
        "test-serial-number-2"
      ]
    },
    {
      "label": "test-group-2",
      "members": [
        "test-serial-number-3",
        "test-serial-number-4"
      ]
    }
  ]
}
```

### Creating Credential Payload
In order to create the credentials payload, you should collapse the JSON payload to a single line and set it like the following

```
$ cf create-user-provided-service luna -p '{"client":{"certificate":"-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----","private-key":"-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"},"servers":[{"name":"test-host-1","certificate":"-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"},{"name":"test-host-2","certificate":"-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"}],"groups":[{"label":"test-group-1","members":["test-serial-number-1","test-serial-number-2"]},{"label":"test-group-2","members":["test-serial-number-3","test-serial-number-4"]}]}'
```

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/luna_security_provider.yml`][] file in the buildpack. The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `ha_logging_enabled` | Whether to enable HA logging for the Luna Security Provider.  Defaults to `true`.
| `logging_enabled` | Whether to enable the logging wrapper for the Luna Security Provider.  Defaults to `false`.
| `repository_root` | The URL of the Luna Security Provider repository index ([details][repositories]).
| `version` | Version of the Luna Security Provider to use.

### Additional Resources
The framework can also be configured by overlaying a set of resources on the default distribution.  To do this, add files to the `resources/luna_security_provider` directory in the buildpack fork.

[`config/luna_security_provider.yml`]: ../config/luna_security_provider.yml
[Luna Security Service]: http://www.safenet-inc.com/data-encryption/hardware-security-modules-hsms/
[Configuration and Extension]: ../README.md#configuration-and-extension
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
