# Azure Application Insights Agent Framework
The Azure Application Insights Agent Framework causes an application to be automatically configured to work with a bound [Azure Application Insights Service][].  **Note:** This framework is disabled by default.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound Azure Application Insights service.
      <ul>
        <li>Existence of a Azure Application Insights service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>azure-application-insights</code> as a substring with at least `connection_string` or `instrumentation_key` set as credentials.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>azure-application-insights=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
Users must provide their own Azure Application Insights service. A user-provided Azure Application Insights service must have a name or tag with `azure-application-insights` in it so that the Azure Application Insights Agent Framework Framework will automatically configure the application to work with the service.

The credential payload of the service has to contain one of the following entries:

| Name | Description
| ---- | -----------
| `connection_string` | With agent version 3.x the connection string is required. You can find your connection string in your Application Insights resource.
| `instrumentation_key` | With agent version 2.x the instrumentation key is required. With version 3.x this configuration is deprecated an it is recommended to switch to a connection string. You can find your instrumentation key in your Application Insights resource.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

[Configuration and Extension]: ../README.md#configuration-and-extension
[Azure Application Insights Service]: https://learn.microsoft.com/en-us/azure/azure-monitor/app/java-in-process-agent
