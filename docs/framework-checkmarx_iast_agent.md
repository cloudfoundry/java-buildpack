# Checkmarx IAST Agent Framework
The Checkmarx IAST Agent Framework causes an application to be automatically configured to work with a bound [Checkmarx IAST Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a bound Checkmarx IAST service. The existence of an Checkmarx IAST service is defined by the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service named <code>checkmarx-iast</code>.
</td>
  </tr>
</table>

## User-Provided Service
When binding Checkmarx IAST using a user-provided service, it must have the name `checkmarx-iast` and the credential payload must include the following entry:

| Name | Description
| ---- | -----------
| `server` | The IAST Manager URL

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

[Checkmarx IAST Service]: https://www.checkmarx.com/products/interactive-application-security-testing
[Configuration and Extension]: ../README.md#configuration-and-extension
