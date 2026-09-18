# Metric Writer Framework
The Metric Writer Framework causes an application to be automatically configured to add Cloud Foundry-specific Micrometer tags.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a <tt>micrometer-core*.jar</tt> file in the application directory</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>metric-writer-reconfiguration=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

The Metric Writer Framework adds a set of CloudFoundry-specific Micrometer tags to any Micrometer metric that does not already contain the keys.  The values of these tags can be explicitly configured via environment variables otherwise they default to values extracted from the standard Cloud Foundry runtime environment.

| Tag | Environment Variable | Default
| --- | ---------------------| -----------
| `cf.account` | `CF_APP_ACCOUNT` | `$VCAP_APPLICATION / cf_api`
| `cf.application` | `CF_APP_APPLICATION`| `$VCAP_APPLICATION / application_name / frigga:name`
| `cf.cluster` | `CF_APP_CLUSTER` | `$VCAP_APPLICATION / application_name / frigga:cluster`
| `cf.version` | `CF_APP_VERSION` | `$VCAP_APPLICATION / application_name / frigga:revision`
| `cf.instance.index` | `CF_APP_INSTANCE_INDEX` | `$CF_INSTANCE_INDEX`
| `cf.organization` | `CF_APP_ORGANIZATION` | `$VCAP_APPLICATION / organization_name`
| `cf.space` | `CF_APP_SPACE` | `$VCAP_APPLICATION / space_name`


## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by setting the `JBP_CONFIG_METRIC_WRITER` environment variable.  The value must be valid inline YAML.

| Name | Description
| ---- | -----------
| `enabled` | Whether to attempt metric augmentation.  Defaults to `false`.

### Example

Enable the metric writer:

```yaml
JBP_CONFIG_METRIC_WRITER: '{enabled: true}'
```

[Configuration and Extension]: ../README.md#configuration-and-extension
