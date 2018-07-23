# Google Stackdriver Profielr Framework
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

The framework can be configured by modifying the [`config/google_stackdriver_profiler.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Google Stackdriver Profiler repository index ([details][repositories]).
| `version` | The version of Google Stackdriver Profiler to use. Candidate versions can be found in [this listing][].

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/google_stackdriver_profiler.yml`]: ../config/google_stackdriver_profiler.yml
[Google Stackdriver Profiler Service]: https://cloud.google.com/profiler/
[repositories]: extending-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/google-stackdriver-profiler/trusty/x86_64/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
