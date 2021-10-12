# Seeker Security Provider Framework
The Seeker Security Provider Framework causes an application to be bound with a [Seeker Security Provider][s] service instance.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound Seeker Security Provider service. The existence of a provider service is defined by the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service name, label or tag with <code>seeker</code> as a substring.
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>seeker-service-provider</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
When binding Appinternals using a user-provided service, it must have <code>seeker</code> as substring. The credential payload must contain the following entries:

| Name | Description
| ---- | -----------
| `seeker_server_url` | The fully qualified URL of a Synopsys Seeker Server (e.g. `https://seeker.example.com`)

**NOTE**
In order to use this integration, the Seeker Server version must be at least `2019.08` or later.
