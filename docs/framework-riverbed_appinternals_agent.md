# Riverbed Appinternals Agent Framework
The Riverbed Appinternals Agent Framework causes an application to be bound with a Riverbed Appinternals service instance.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound Riverbed Appinternals agent service. The existence of an agent service is defined by the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service name, label or tag with <code>appinternals</code> as a substring.
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>riverbed-appinternals-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
When binding Appinternals using a user-provided service, it must have <code>appinternals</code> as substring. The credential payload can contain the following entries: 

| Name | Description
| ---- | -----------
| `rvbd_dsa_port` | (Optional)The AppInternals agent (DSA) port (default 2111).
| `rvbd_agent_port` | (Optional) The AppInternals agent socket port (default 7073).
| `rvbd_moniker` | (Optional) A custom name for the application (default supplied by agent process discovery).

**NOTE**

Change `rvbd_dsa_port` and `rvbd_agent_port` only if there is a port conflict

### Example: Creating Riverbed Appinternals User-Provided Service Payload

``` 
cf cups spring-music-appinternals -p '{"rvbd_dsa_port":"9999","rvbd_moniker":"my_app"}'
cf bind-service spring-music spring-music-appinternals
```

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/riverbed_appinternals_agent.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Riverbed Appinternals agent repository index ([details][repositories]).
| `version` | The version of the Riverbed Appinternals agent to use.

[Configuration and Extension]: ../README.md#configuration-and-extension
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
[`config/riverbed_appinternals_agent.yml`]: ../config/riverbed_appinternals_agent.yml


**NOTE**

If the Riverbed Service Broker's version is greater than or equal to 10.20, the buildpack will instead download Riverbed AppInternals agent from Riverbed Service Broker and will fall back to using `repository_root` in [`config/riverbed_appinternals_agent.yml`][] only if Service Broker failed to serve the Agent artifact.

**NOTE**

If the Rivered verstion is 10.21.9 or later, the buildpack will load the profiler normally, instead of from the Service Broker. This allows for creating multiple offline buildpacks containing different versions.
