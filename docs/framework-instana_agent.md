# Instana Agent Framework
[IBM Instana](https://www.ibm.com/products/instana)  is the only real-time full-stack observability solution: zero sample tracing

The Instana Agent Framework causes an application to be automatically configured to work with a bound Instana instance

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound Instana service.
      <ul>
        <li>Existence of a Instana service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>instana</code> as a substring with at least `agentkey` and `endpointurl` set as credentials.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>instana-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
Users must provide their own Instana service. A user-provided Instana service must have a name or tag with `instana` in it so that the Instana Framework will automatically configure the application to work with the service.

The credential payload of the service may contain the following entries:

| Name | Description
| ---- | -----------
| `agentkey` | The agent key is used to create a relationship between the monitoring agent and the environment that it belongs to.
| `endpointurl` | This environment variable is your serverless monitoring endpoint. Make sure that you use the correct value for your region that starts with https://serverless-.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

[Configuration and Extension]: ../README.md#configuration-and-extension

