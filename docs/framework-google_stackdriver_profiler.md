# Google Stackdriver Profiler Framework
The Google Stackdriver Profiler Framework causes an application to be automatically configured to work with a bound [Google Stackdriver Profiler Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound Google Stackdriver Profiler service.
      <ul>
        <li>Existence of a Google Stackdriver Profiler service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>google-stackdriver-profiler</code> as a substring.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>google-stackdriver-profiler=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service (Optional)
Users may optionally provide their own Google Stackdriver Profiler service. A user-provided Google Stackdriver Profiler service must have a name or tag with `google-stackdriver-profiler` in it so that the Google Stackdriver Profiler Agent Framework will automatically configure the application to work with the service.

The credential payload of the service must contain the following entry:

| Name | Description
| ---- | -----------
| `PrivateKeyData` | A Base64 encoded Service Account JSON payload

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by setting the `JBP_CONFIG_GOOGLE_STACKDRIVER_PROFILER` environment variable.  The value must be valid inline YAML.

| Name | Description
| ---- | -----------
| `application_name` | Override the application name reported to Stackdriver.  Defaults to the value from `VCAP_APPLICATION`.
| `application_version` | Override the application version reported to Stackdriver.  Defaults to the value from `VCAP_APPLICATION`.

### Example

Override application name and version:

```yaml
JBP_CONFIG_GOOGLE_STACKDRIVER_PROFILER: '{application_name: my-app, application_version: 1.2.3}'
```

[Configuration and Extension]: ../README.md#configuration-and-extension
[Google Stackdriver Profiler Service]: https://cloud.google.com/profiler/
