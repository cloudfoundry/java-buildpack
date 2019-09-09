# YourKit Profiler Framework
The YourKit Profiler Framework contributes YourKit Profiler configuration to the application at runtime.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td><tt>enabled</tt> set in the <tt>config/your_kit_profiler.yml</tt> file</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>your-kit-profiler=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by creating or modifying the [`config/your_kit_profiler.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `default_session_name` | The session name to display in the YourKit Profiler UI.  Defaults to `<APPLICATION_NAME>:<INSTANCE_INDEX>`.
| `enabled` | Whether to enable the YourKit Profiler
| `port` | The port that the YourKit Profiler will listen on.  Defaults to `10001`.
| `repository_root` | The URL of the YourKit Profiler repository index ([details][repositories]).
| `version` | The version of the YourKit Profiler to use. Candidate versions can be found in the listings for [bionic][].

## Creating SSH Tunnel
After starting an application with the YourKit Profiler enabled, an SSH tunnel must be created to the container.  To create that SSH container, execute the following command:

```bash
$ cf ssh -N -T -L <LOCAL_PORT>:localhost:<REMOTE_PORT> <APPLICATION_NAME>
```

The `REMOTE_PORT` should match the `port` configuration for the application (`10001` by default).  The `LOCAL_PORT` can be any open port on your computer, but typically matches the `REMOTE_PORT` where possible.

Once the SSH tunnel has been created, your YourKit Profiler should connect to `localhost:<LOCAL_PORT>` for debugging.

![YourKit Configuration](framework-your_kit_profiler.png)

[`config/your_kit_profiler.yml`]: ../config/your_kit_profiler.yml
[bionic]: https://download.run.pivotal.io/your-kit/bioni/x86_64/index.yml
[Configuration and Extension]: ../README.md#configuration-and-extension
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
