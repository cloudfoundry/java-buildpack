# DynaTrace Agent Framework
The DynaTrace Agent Framework causes an application to be automatically configured to work with a bound [DynaTrace Service][] instance (Free trials available).

The Cloud Foundry pushed application name is used as the `agent group` in DynaTrace, and must be pre-configured on the DynaTrace server.
A system profile may be provided as an optional argument (defaults to `Monitoring`).

**Current Issues:**  
* The DynaTrace agent slows down app execution significantly at first, but gets faster over time.  You may want to update your CF deployment manifest to set `maximum_health_check_timeout` to 180 or more and/or execute `cf push -t 180` or more when pushing a DynaTrace-monitored application.

* As you `cf push` multiple times, many dead penguins will litter the DynaTrace agent dashboard, as CF launches/disposes application containers.  These can be hidden but will collect in the dynatrace database.

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
| `server` | The DynaTrace collector hostname to connect to.   Use `host:port` format for a specific port number.
| `profile` | (optional) The DynaTrace server profile this is associated with.   Uses `Monitoring` by default.

**NOTE** Be sure to open an Application Security Group to your DynaTrace collector prior to starting your application:
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

The framework can be configured by modifying the [`dyna_trace_agent.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the DynaTrace repository index ([details][repositories]).
| `version` | The version of DynaTrace to use. This buildpack framework has been tested on 6.1.0.


**NOTE:**  This framework does not connect to a pre-populated repository.  Instead you will need to create your own repository by:

1.  Downloading the DynaTrace agent unix binary (in JAR format) to an HTTP-accesible location
1.  Uploading an `index.yml` file with a mapping from the version of the agent to its location to the same HTTP-accessible location
1.  Configuring the [`dyna_trace_agent.yml`][] file to point to the root of the repository holding both the index and agent binary

Sample **`repository_root`** for [`dyna_trace_agent.yml`][] (under java-buildpack/config) assuming a bosh-lite setup and a local webserver (e.g. `brew install tomcat7`) on port 8080

```
repository_root: "http://files.192.168.50.1.xip.io:8080/fileserver/dynatrace"
```

The buildpack would look for an **`index.yml`** file at the specified **repository_root** for obtaining the DynaTrace agent.

The index.yml at the repository_root location should have a entry matching the DynaTrace version and the corresponding DynaTrace agent download JAR

```
---
6.1.0.7880: http://files.192.168.50.1.xip.io:8080/fileserver/dynatrace/dynatrace-agent-6.1.0.7880-unix.jar
```

Ensure the DynaTrace binary is available at the location indicated by the index.yml referred by the DynaTrace repository_root.

[Configuration and Extension]: ../README.md#configuration-and-extension
[`dyna_trace_agent.yml`]: ../config/dyna_trace_agent.yml
[DynaTrace Service]: https://dynatrace.com
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
