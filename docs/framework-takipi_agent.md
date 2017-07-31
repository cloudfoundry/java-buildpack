# Takipi Agent Framework
The Takipi Agent Framework causes an application to be automatically configured to work with [OverOps Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound Takipi service. The existence of an Takipi service defined by the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service name, label or tag with <code>app-dynamics</code> or <code>takipi</code> as a substring.
</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>takipi-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
When binding Takipi using a user-provided service, it must have name or tag with `takipi` in it.
The credential payload can contain the following entries. 

| Name | Description
| ---- | -----------
| `secret_key` | (Optional) The agent installation key
| `collector_host` | (Optional) The remote collector hostname or IP 
| `collector_port` | (Optional) the remote collector port

Setting `secret_key` will run a local collector alongside the agent. Setting `collector_host` will use a remote collector. More information can be found in [OverOps Remote Collector][]

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/takipi_agent.yml`][] file. The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `node_name_prefix` | Node name prefix, will be concatenated with `-` and instance index
| `application_name` | Override the Cloudfoundry default application name

## Logs

Currently, you can get the Takipi agent logs using `cf files` command:
```
cf files app_name app/.java-buildpack/takipi_agent/log/
```

[`config/takipi_agent.yml`]: ../config/takipi_agent.yml
[Configuration and Extension]: ../README.md#configuration-and-extension
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
[OverOps Remote Collector]: https://support.overops.com/hc/en-us/articles/227109628-Remote-Daemon-Process-
[OverOps Service]: https://www.overops.com
