# AspectJ Weaver Agent Framework
The AspectJ Weaver Agent Framework configures the AspectJ Runtime Weaving Agent at runtime.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td><tt>aspectjweaver-*.jar</tt> existing and <tt>BOOT-INF/classes/META-INF/aop.xml</tt>, <tt>BOOT-INF/classes/org/aspectj/aop.xml</tt>, <tt>META-INF/aop.xml</tt>, or <tt>org/aspectj/aop.xml</tt> existing.</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>aspectj-weaver-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by creating or modifying the [`config/aspectj_weaver_agent.yml`][] file in the buildpack fork.

| Name | Description
| ---- | -----------
| `enabled` | Whether to enable the AspectJ Runtime Weaving agent.

[`config/aspectj_weaver_agent.yml`]: ../config/aspect_weaver_agent.yml
[Configuration and Extension]: ../README.md#configuration-and-extension
