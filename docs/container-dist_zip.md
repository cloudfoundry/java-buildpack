# Dist Zip Container
The Dist Zip Container allows applications packaged in [`distZip`-style][] to be run.

<table>
  <tr>
    <td><strong>Detection Criteria</strong></td>
    <td><ul>
      <li>A start script in the <code>bin/</code> subdirectory of the application directory or one of its immediate subdirectories (but not in both) - for example, a <code>bin</code> folder with: <code>bin/myscript</code> along with <code>bin/myscript.bat</code>, and</li>
      <li>A JAR file in the <code>lib/</code> subdirectory of the application directory or one of its immediate subdirectories (but not in both)</li>
    </ul></td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><code>dist-zip</code></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

If the application uses Spring, [Spring profiles][] can be specified by setting the [`SPRING_PROFILES_ACTIVE`][] environment variable. This is automatically detected and used by Spring. The Spring Auto-reconfiguration Framework will specify the `cloud` profile in addition to any others.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The container can be configured by modifying the `config/dist_zip.yml` file in the buildpack fork.

| Name | Description
| ---- | -----------
| `arguments` | Optional command line arguments to be passed to the start script. The arguments are specified as a single YAML scalar in plain style or enclosed in single or double quotes.

[Configuration and Extension]: ../README.md#configuration-and-extension
[`distZip`-style]: http://www.gradle.org/docs/current/userguide/application_plugin.html
[Spring profiles]:http://blog.springsource.com/2011/02/14/spring-3-1-m1-introducing-profile/
[`SPRING_PROFILES_ACTIVE`]: http://static.springsource.org/spring/docs/3.1.x/javadoc-api/org/springframework/core/env/AbstractEnvironment.html#ACTIVE_PROFILES_PROPERTY_NAME
