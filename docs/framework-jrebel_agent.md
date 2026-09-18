# JRebel Agent Framework

The JRebel Agent Framework causes an application to be automatically configured to work with [JRebel][]. Pushing any [JRebel Cloud/Remote][] enabled application (containing `rebel-remote.xml`) will automatically download the latest version of [JRebel][] and set it up for use.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a <tt>rebel-remote.xml</tt> file inside the application archive. This file is present in every application that is configured to use <a href="http://manuals.zeroturnaround.com/jrebel/remoteserver/index.html" target="_blank">JRebel Cloud/Remote</a>.</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>jrebel-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

For more information regarding setup and configuration, please refer to the [JRebel with Pivotal Cloud Foundry tutorial][pivotal].

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by setting the `JBP_CONFIG_JREBEL` environment variable.  The value must be valid inline YAML.

| Name | Description
| ---- | -----------
| `enabled` | Whether to activate JRebel upon the presence of `rebel-remote.xml`.  Defaults to `true`.

### Example

Disable JRebel even when `rebel-remote.xml` is present:

```yaml
JBP_CONFIG_JREBEL: '{enabled: false}'
```

[Configuration and Extension]: ../README.md#configuration-and-extension
[JRebel Cloud/Remote]: http://manuals.zeroturnaround.com/jrebel/remoteserver/index.html
[JRebel]: http://zeroturnaround.com/software/jrebel/
[pivotal]: http://manuals.zeroturnaround.com/jrebel/remoteserver/pivotal.html
