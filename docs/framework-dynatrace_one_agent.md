# Dynatrace SaaS/Managed OneAgent Framework
[Dynatrace SaaS/Managed](http://www.dynatrace.com/cloud-foundry/) is your full stack monitoring solution - powered by artificial intelligence. Dynatrace SaaS/Managed allows you insights into all application requests from the users click in the browser down to the database statement and code-level.

The Java buildpack uses the [libbuildpack-dynatrace](https://github.com/Dynatrace/libbuildpack-dynatrace) library to automatically configure applications to work with a bound [Dynatrace SaaS/Managed Service][] instance (Free trials available).

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound Dynatrace SaaS/Managed service.
      <ul>
        <li>Existence of a Dynatrace SaaS/Managed service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>dynatrace</code> as a substring with at least `environmentid` and `apitoken` set as credentials.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>dynatrace-one-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Implementation
This buildpack integrates with Dynatrace using the [libbuildpack-dynatrace](https://github.com/Dynatrace/libbuildpack-dynatrace) hook library (v1.8.0). This is the same integration library used by all modern Cloud Foundry buildpacks (Go, Node.js, Python, PHP, etc.), ensuring consistent behavior across the platform.

The integration:
- Downloads and installs the Dynatrace OneAgent using the official PaaS installer
- Configures `LD_PRELOAD` to inject the agent into the Java process
- Fetches and merges the latest agent configuration from the Dynatrace API
- Supports FIPS mode, network zones, and additional technologies
- Provides retry logic and error handling for robust deployments

## User-Provided Service
Users must provide their own Dynatrace SaaS/Managed service. A user-provided Dynatrace SaaS/Managed service must have a name or tag with `dynatrace` in it so that the Dynatrace Saas/Managed OneAgent Framework will automatically configure the application to work with the service.

The credential payload of the service may contain the following entries:

| Name | Description
| ---- | -----------
| `apitoken` | The token for integrating your Dynatrace environment with Cloud Foundry. You can find it in the deploy Dynatrace section within your environment.
| `apiurl` | (Optional) The base URL of the Dynatrace API. If you are using Dynatrace Managed you will need to set this property to `https://<your-managed-server-url>/e/<environmentId>/api`. If you are using Dynatrace SaaS you don't need to set this property.
| `environmentid` | Your Dynatrace environment ID is the unique identifier of your Dynatrace environment. You can find it in the deploy Dynatrace section within your environment.
| `networkzone` | (Optional) Network zones are Dynatrace entities that represent your network structure. They help you to route the traffic efficiently, avoiding unnecessary traffic across data centers and network regions. Enter the network zone you wish to pass to the server during the OneAgent Download.
| `skiperrors` | (Optional) The errors during agent download are skipped and the injection is disabled. Use this option at your own risk. Possible values are 'true' and 'false'. This option is disabled by default!
| `enablefips`| (Optional) Enables the use of [FIPS 140 cryptographic algorithms](https://docs.dynatrace.com/docs/shortlink/oneagentctl#fips-140). Possible values are 'true' and 'false'. This option is disabled by default!
| `addtechnologies` | (Optional) Adds additional OneAgent code-modules via a comma-separated list. See [supported values](https://docs.dynatrace.com/docs/dynatrace-api/environment-api/deployment/oneagent/download-oneagent-version#parameters) in the "included" row|
| `customoneagenturl` | (Optional) Custom download URL for OneAgent. If set, `apiurl`, `environmentid`, and `apitoken` are not required.|

Example:
```bash
cf create-user-provided-service dynatrace -p '{"environmentid":"abc12345","apitoken":"dt0c01.ABC...XYZ"}'
cf bind-service my-app dynatrace
cf restage my-app
```

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

## Support
For questions about the buildpack integration, please open an issue on the [java-buildpack GitHub repository](https://github.com/cloudfoundry/java-buildpack).

For questions about Dynatrace itself, visit [Dynatrace support](https://support.dynatrace.com/).

For technical details about the integration library, see [libbuildpack-dynatrace](https://github.com/Dynatrace/libbuildpack-dynatrace).

[Configuration and Extension]: ../README.md#configuration-and-extension
[Dynatrace SaaS/Managed Service]: http://www.dynatrace.com/cloud-foundry/
