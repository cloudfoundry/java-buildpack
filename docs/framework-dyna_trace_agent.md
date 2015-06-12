# DynaTrace Agent Framework
The DynaTrace Agent Framework causes an application to be automatically configured to work with a bound [DynaTrace Service][] instance (Free trials available).

The applications Cloud Foundry name is used as the `agent group` in DynaTrace, and must be pre-configured on the DynaTrace server.

**NOTE**  

* The DynaTrace agent slows down app execution significantly at first, but gets faster over time. Setting the application manifest to contain `maximum_health_check_timeout` of 180 or more and/or using `cf push -t 180` or more when pushing a DynaTrace-monitored application may help.
* Multiple `cf push`s will cause dead penguins to build up in the DynaTrace agent dashboard, as CF launches/disposes application containers. These can be hidden but will collect in the dynatrace database.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound DynaTrace service.
      <ul>
        <li>Existence of a DynaTrace service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>dynatrace</code> as a substring.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>dyna-trace-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
Users must provide their own DynaTrace service. A user-provided DynaTrace service must have a name or tag with `dynatrace` in it so that the DynaTrace Agent Framework will automatically configure the application to work with the service.

The credential payload of the service may contain the following entries:

| Name | Description
| ---- | -----------
| `server` | The DynaTrace collector hostname to connect to. Use `host:port` format for a specific port number.
| `profile` | (Optional) The DynaTrace server profile this is associated with. Uses `Monitoring` by default.

**NOTE** 

Be sure to open an Application Security Group to your DynaTrace collector prior to starting the application:
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
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/dyna_trace_agent.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the DynaTrace repository index ([details][repositories]).
| `version` | The version of DynaTrace to use. This buildpack framework has been tested on 6.1.0.

### Additional Resources
The framework can also be configured by overlaying a set of resources on the default distribution.  To do this, add files to the `resources/ca_wily_agent` directory in the buildpack fork.  For example, to override the default profile add your custom profile to `resources/introscope_agent/`.

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/dyna_trace_agent.yml`]: ../config/dyna_trace_agent.yml
[DynaTrace Service]: https://dynatrace.com
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
