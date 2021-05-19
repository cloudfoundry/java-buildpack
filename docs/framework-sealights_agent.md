# Sealights Agent Framework
The Sealights Agent Framework causes an application to be automatically configured to work with [Sealights Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound sealights service. The existence of a sealights service defined by the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service name, label or tag with <code>sealights</code> as a substring.
</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>sealights-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
When binding Sealights using a user-provided service, it must have name or tag with `sealights` in it.
The credential payload can contain the following entries. 

| Name | Description
| ---- | -----------
| `token` | A Sealights Agent token

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/sealights_agent.yml`][] file. The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `build_session_id` | Sealights [Build Session ID][] for the application. Leave blank to use the value embedded in the jar/war artifacts
| `proxy` | Specify a HTTP proxy used to communicate with the Sealights backend. Required when a corporate network prohibits communication to cloud services. The default is to have no proxy configured. This does not inherit from `http_proxy`/`https_proxy` or `http.proxyHost/https.proxyHost`, you must set this specifically if a proxy is needed.
| `lab_id` | Specify a Sealights [Lab ID][]
| `auto_upgrade` | Enable/disable agent auto-upgrade. Off by default
| `version` | The version of Auto-reconfiguration to use. Candidate versions can be found in [this listing][]. If auto_upgrade is turned on, a different version may be downloaded and used at runtime

## Troubleshooting and Support

For additional documentation and support, visit the official [Sealights Java agents documentation] page

[`config/sealights_agent.yml`]: ../config/sealights_agent.yml
[Configuration and Extension]: ../README.md#configuration-and-extension
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
[Sealights Service]: https://www.sealights.io
[Build Session ID]: https://sealights.atlassian.net/wiki/spaces/SUP/pages/3473472/Using+Java+Agents+-+Generating+a+session+ID
[Lab ID]: https://sealights.atlassian.net/wiki/spaces/SUP/pages/762413124/Using+Java+Agents+-+Running+Tests+in+Parallel+Lab+Id
[this listing]: https://agents.sealights.co/pcf/index.yml
[Sealights Java agents documentation]: https://sealights.atlassian.net/wiki/spaces/SUP/pages/3014685/SeaLights+Java+agents
