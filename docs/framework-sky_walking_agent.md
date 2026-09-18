# SkyWalking Agent Framework
The SkyWalking Agent Framework causes an application to be automatically configured to work with a bound [SkyWalking Service][]  **Note:** This framework is disabled by default.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound SkyWalking service. The existence of an SkyWalking service defined by the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service name, label or tag with <code>sky-walking</code> or <code>skywalking</code> as a substring.
</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>sky-walking-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
When binding SkyWalking using a user-provided service, it must have name or tag with `sky-walking` or `skywalking` in it. The credential payload can contain the following entries.  **Note:** Credentials marked as "(Optional)" may be required for some versions of the SkyWalking agent.  Please see the [SkyWalking Java Agent Configuration Properties][] for the version of the agent used by your application for more details.

| Name | Description
| ---- | -----------
| `collector_backend_services` | The collector backend address(es). Examples: single collector — `127.0.0.1:11800`; cluster — `10.2.45.126:11800,10.2.45.127:11800`. Also accepted as `collectorBackendServices` or `backend_service`.
| `sample-n-per-3-secs` | (Optional) The number of sampled traces per 3 seconds. Negative number means sample traces as many as possible, most likely 100%
| `span-limit-per-segment` | (Optional) The max amount of spans in a single segment
| `ignore-suffix` |  (Optional) Ignore the segments if their operation names start with these suffix
| `open-debugging-class` | (Optional) If true, skywalking agent will save all instrumented classes files in `/debugging` folder.Skywalking team may ask for these files in order to resolve compatible problem
| `logging-level` | (Optional) Logging level

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by setting the `JBP_CONFIG_SKY_WALKING_AGENT` environment variable.  The value must be valid inline YAML.

| Name | Description
| ---- | -----------
| `default_application_name` | Fallback application name used in the SkyWalking dashboard **only when `VCAP_APPLICATION` is not available** (i.e. outside a Cloud Foundry container).  On Cloud Foundry, `VCAP_APPLICATION.application_name` is always used instead, prefixed with the space name (`space:app`), and this setting is ignored.

### Application name resolution order

1. **`VCAP_APPLICATION`** — the buildpack reads `space_name` and `application_name` from this variable and sets the service name to `<space>:<app>`.  This is the value used for every normal Cloud Foundry deployment; `default_application_name` has no effect here.
2. **`default_application_name`** (fallback) — used only when `VCAP_APPLICATION` is absent or unparseable (e.g. running the agent outside Cloud Foundry).

### Example

Set a fallback name for non-CF environments:

```yaml
JBP_CONFIG_SKY_WALKING_AGENT: '{default_application_name: my-service}'
```

### Additional Resources

**Note:** The `resources/sky_walking_agent` directory approach from the Ruby buildpack (2013-2025) is no longer supported. This was a **buildpack-level** feature where teams would fork the java-buildpack repository, add custom files to `resources/sky_walking_agent/`, and package their custom buildpack. The Go buildpack does not package the `resources/` directory.

[SkyWalking Java Agent Configuration Properties]: https://github.com/apache/incubator-skywalking/blob/master/docs/en/Deploy-skywalking-agent.md
[SkyWalking Service]: http://skywalking.io
[Configuration and Extension]: ../README.md#configuration-and-extension
