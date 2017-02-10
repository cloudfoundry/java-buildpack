# Dynatrace Appmon Agent Framework
The Dynatrace Appmon Agent Framework causes an application to be automatically configured to work with a bound [Dynatrace Service][] instance (Free trials available).

The application's Cloud Foundry name is used as the `agent group` in Dynatrace Appmon, and must be pre-configured on the Dynatrace server.

**NOTE**  

* The Dynatrace Appmon agent may slow down the start up time of large applications at first, but gets faster over time. Setting the application manifest to contain `maximum_health_check_timeout` of 180 or more and/or using `cf push -t 180` or more when pushing the application may help.
* Unsuccessful `cf push`s will cause dead entries to build up in the Dynatrace Appmon dashboard, as CF launches/disposes application containers. These can be hidden but will collect in the Dynatrace database.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound Dynatrace Appmon service.
      <ul>
        <li>Existence of a Dynatrace Appmon service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>dynatrace</code> as a substring and contains <code>server</code> field in the credentials. Note: The credentials must <b>NOT</b> contain <code>tenant</code> and <code>tenanttoken</code> in order to make sure the detection mechanism does not interfere with Dynatrace SaaS/Managed integration.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>dynatrace-appmon-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
Users must provide their own Dynatrace Appmon service. A user-provided Dynatrace Appmon service must have a name or tag with `dynatrace` in it so that the Dynatrace Appmon Agent Framework will automatically configure the application to work with the service.

The credential payload of the service may contain the following entries:

| Name | Description
| ---- | -----------
| `server` | The Dynatrace collector hostname to connect to. Use `host:port` format for a specific port number.
| `profile` | (Optional) The Dynatrace server profile this is associated with. Uses `Monitoring` by default.

### Example Dynatrace User-Provided Service Payload
```
{
  "server":"my-dynatrace-server:my-port",
  "profile":"my-dynatrace-profile"
}
```

### Creating Dynatrace User-Provided Service Payload
In order to create the Dynatrace configuration payload, you should collapse the JSON payload to a single line and set it like the following... The user-provided Dynatrace Appmon service must have a name of or tag with `dynatrace` in it.  For example: my-dynatrace-service.  

``` 
cf cups my-dynatrace-service -p '{"server":"my-dynatrace-server:my-port","profile":"my-dynatrace-profile"}'
cf bind-service my-app-name my-dynatrace-service
```

**NOTE**

Be sure to open an Application Security Group to your Dynatrace collector prior to starting the application:
```
$ cat security.json
   [
     {
       "protocol": "tcp",
       "destination": "dynatrace_host",
       "ports": "9998"
     }
   ]

$ cf create-security-group dynatrace_group ./security.json
Creating security group dynatrace_group as admin
OK

$ cf bind-running-security-group dynatrace_group
Binding security group dynatrace_group to defaults for running as admin
OK

TIP: Changes will not apply to existing running applications until they are restarted.
```

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/dynatrace_appmon_agent.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Dynatrace Appmon repository index ([details][repositories]).
| `version` | The version of Dynatrace Appmon to use. This buildpack framework has been tested on 6.1.0.
| `default_agent_name` | This is omitted by default but can be added to set the Dynatrace Appmon agent name. If it is not specified then `#{application_name}_#{profile_name}` is used, where `application_name` is defined by Cloud Foundry.

### Additional Resources
The framework can also be configured by overlaying a set of resources on the default distribution. To do this, add files to the `resources/dynatrace_appmon_agent` directory in the buildpack fork.

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/dynatrace_appmon_agent.yml`]: ../config/dynatrace_appmon_agent.yml
[Dynatrace Service]: https://www.dynatrace.com/
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
