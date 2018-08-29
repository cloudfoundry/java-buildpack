# JMX Framework
The JMX Framework contributes Java JMX configuration to the application at runtime.  **Note:** This framework is only useful in Diego-based containers with SSH access enabled.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td><tt>enabled</tt> set in the <tt>config/jmx.yml</tt> file</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>jmx=&lt;port&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by creating or modifying the [`config/jmx.yml`][] file in the buildpack fork.

| Name | Description
| ---- | -----------
| `enabled` | Whether to enable JMX
| `port` | The port that the debug agent will listen on.  Defaults to `5000`.

## Creating SSH Tunnel
After starting an application with JMX enabled, an SSH tunnel must be created to the container.  To create that SSH container, execute the following command:

```bash
$ cf ssh -N -T -L <LOCAL_PORT>:localhost:<REMOTE_PORT> <APPLICATION_NAME>
```

The `REMOTE_PORT` should match the `port` configuration for the application (`5000` by default).  The `LOCAL_PORT` must match the `REMOTE_PORT`.

Once the SSH tunnel has been created, your JConsole should connect to `localhost:<LOCAL_PORT>` for JMX access.

![JConsole Configuration](framework-jmx-jconsole.png)

[`config/jmx.yml`]: ../config/jmx.yml
[Configuration and Extension]: ../README.md#configuration-and-extension
