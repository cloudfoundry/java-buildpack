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
| `application-name` | (Optional) The application's name
| `sample-n-per-3-secs` | (Optional) The number of sampled traces per 3 seconds. Negative number means sample traces as many as possible, most likely 100%
| `span-limit-per-segment` | (Optional) The max amount of spans in a single segment
| `ignore-suffix` |  (Optional) Ignore the segments if their operation names start with these suffix
| `open-debugging-class` | (Optional) If true, skywalking agent will save all instrumented classes files in `/debugging` folder.Skywalking team may ask for these files in order to resolve compatible problem
| `servers` |  Server addresses .Examples: Single collector：servers="127.0.0.1:8080",Collector cluster：servers="10.2.45.126:8080,10.2.45.127:7600"
| `logging-level` | (Optional) Logging level

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/sky_walking_agent.yml`][] file in the buildpack fork. The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `default_application_name` | This is omitted by default but can be added to specify the application name in the SkyWalking dashboard. This can be overridden by an `application-name` entry in the credentials payload. If neither are supplied the default is the `application_name` as specified by Cloud Foundry.
| `repository_root` | The URL of the SkyWalking repository index ([details][repositories]).
| `version` | The version of SkyWalking to use. Candidate versions can be found in [this listing][].

### Additional Resources
The framework can also be configured by overlaying a set of resources on the default distribution. To do this, add files to the `resources/sky_walking_agent` directory in the buildpack fork.

[`config/sky_walking_agent.yml`]: ../config/sky_walking_agent.yml
[SkyWalking Java Agent Configuration Properties]: https://github.com/apache/incubator-skywalking/blob/master/docs/en/Deploy-skywalking-agent.md
[SkyWalking Service]: http://skywalking.io
[Configuration and Extension]: ../README.md#configuration-and-extension
[repositories]: extending-repositories.md
[this listing]: https://download.run.pivotal.io/sky-walking/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
