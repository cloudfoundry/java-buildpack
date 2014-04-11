# Ratpack Container
The Ratpack Container allows [Ratpack][r] applications, packaged `distZip`-style to be run.

<table>
  <tr>
    <td><strong>Detection Criteria</strong></td>
    <td>The <tt>lib/ratpack-core-.*.jar</tt> file exists in either the top-level directory or an immediate subdirectory of the application.</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>ratpack=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

The container expects to run the application creating by running [`gradle distZip`][d] in an application built with the Ratpack Gradle plugin.

## Configuration
The Ratpack Container cannot be configured.

[d]: http://www.ratpack.io/manual/current/setup.html#using_the_gradle_plugins
[r]: http://www.ratpack.io
