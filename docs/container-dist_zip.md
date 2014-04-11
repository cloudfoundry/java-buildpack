# Dist Zip Container
The Dist Zip Container allows applications packaged in [`distZip`-style][] to be run.

<table>
  <tr>
    <td><strong>Detection Criteria</strong></td>
    <td><ul>
      <li>A start script in the <tt>bin/</tt> subdirectory of the application directory or one of its immediate subdirectories (but not in both), and</li>
      <li>A JAR file in the <tt>lib/</tt> subdirectory of the application directory or one of its immediate subdirectories (but not in both)</li>
    </ul></td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>dist-zip</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
The Dist Zip Container cannot be configured.


[`distZip`-style]: http://www.gradle.org/docs/current/userguide/application_plugin.html
