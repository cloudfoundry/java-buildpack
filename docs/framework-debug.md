# Debug Framework
The Debug Framework contributes Java debug configuration to the application at runtime.  **Note:** This framework is only useful in Diego-based containers with SSH access enabled.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td><tt>enabled</tt> set in the <tt>config/debug.yml</tt> file</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>debug</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by creating or modifying the [`config/debug.yml`][] file in the buildpack fork.

| Name | Description
| ---- | -----------
| `enabled` | Whether to enable Java debuging
| `port` | The port that the debug agent will listen on
| `suspend` | Whether to suspend execution until a debugger has attached.  Note, enabling this may cause application start to timeout and be restarted.

[`config/debug.yml`]: ../config/debug.yml
[Configuration and Extension]: ../README.md#configuration-and-extension
