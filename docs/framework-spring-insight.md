# Spring Insight Framework
The Spring Insight Framework causes an application to be automatically configured to work with a bound [Spring Insight Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound Spring Insight service. The existence of a Spring Insight service defined by the <a href="http://docs.cloudfoundry.com/docs/using/deploying-apps/environment-variable.html#VCAP_SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service name-version, name, label or tag with <code>insight</code> as a substring.
</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>spring-insight=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
When binding Spring Insight as a user-provided service, it must have name, label, or tag with <code>insight</code> as a substring.  The credential payload contains the following entries:

| Name | Description
| ---- | -----------
| `dashboard_url` | The URL via which users access the Spring Insight dashboard.

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The framework is configured entirely via <code>VCAP_SERVICES</code>. It is not configurable via the buildpack (although an empty configuration file [`config/springinsight.yml`][] is present).

[`config/springinsight.yml`]: ../config/springinsight.yml
[Spring Insight Service]: http://gopivotal.com/pivotal-products/apps/pivotal-tc-server
[Configuration and Extension]: ../README.md#Configuration-and-Extension
