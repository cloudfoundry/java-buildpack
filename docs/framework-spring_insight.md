# Spring Insight Framework
The Spring Insight Framework causes an application to be automatically configured to work with a bound [Spring Insight Service][]. This feature will only work with Spring Insight versions of 2.0.0.x or above.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a single bound Spring Insight service.
      <ul>
        <li>Existence of a Spring Insight service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>insight</code> as a substring.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>spring-insight=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
When binding Spring Insight using a user-provided service, it must have name or tag with `insight` in it.  The credential payload must contain the following entries:

| Name | Description
| ---- | -----------
| `dashboard_url` | The URL via which users access the Spring Insight dashboard.

## Configuration
The Spring Insight Framework cannot be configured.

[Spring Insight Service]: http://gopivotal.com/pivotal-products/apps/pivotal-tc-server
