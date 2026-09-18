# JProfiler Profiler Framework
The JProfiler Profiler Framework contributes JProfiler configuration to the application at runtime.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td><tt>enabled</tt> set via <tt>JBP_CONFIG_JPROFILER_PROFILER</tt></td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>jprofiler-profiler=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by setting the `JBP_CONFIG_JPROFILER_PROFILER` environment variable.  The value must be valid inline YAML.

| Name | Description
| ---- | -----------
| `enabled` | Whether to enable the JProfiler Profiler.  Defaults to `false`.
| `port` | The port that the JProfiler Profiler will listen on.  Defaults to `8849`.
| `nowait` | Whether to start the process without waiting for JProfiler to connect first.  Defaults to `true`.

### Examples

Enable JProfiler on the default port:

```yaml
JBP_CONFIG_JPROFILER_PROFILER: '{enabled: true}'
```

Enable JProfiler on a custom port, waiting for connection:

```yaml
JBP_CONFIG_JPROFILER_PROFILER: '{enabled: true, port: 9000, nowait: false}'
```

## Creating SSH Tunnel
After starting an application with the JProfiler Profiler enabled, an SSH tunnel must be created to the container.  To create that SSH container, execute the following command:

```bash
$ cf ssh -N -T -L <LOCAL_PORT>:localhost:<REMOTE_PORT> <APPLICATION_NAME>
```

The `REMOTE_PORT` should match the `port` configuration for the application (`8849` by default).  The `LOCAL_PORT` can be any open port on your computer, but typically matches the `REMOTE_PORT` where possible.

Once the SSH tunnel has been created, your JProfiler Profiler should connect to `localhost:<LOCAL_PORT>` for debugging.

![JProfiler Configuration](framework-jprofiler_profiler.png)

[Configuration and Extension]: ../README.md#configuration-and-extension
