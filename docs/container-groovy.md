# Groovy Container
The Groovy Container allows uncompiled Groovy files (i.e. `*.groovy`) to be run.

<table>
  <tr>
    <td><strong>Detection Criteria</strong></td>
    <td><ul>
      <li>A <tt>.groovy</tt> file exists which has a <tt>main()</tt> method, or</li>
      <li>A <tt>.groovy</tt> file exists which is not a POGO (a POGO contains one or more classes), or</li>
      <li>A <tt>.groovy</tt> file exists which has a shebang (<tt>#!</tt>) declaration</li>
    </ul>and<ul>
      <li>No <tt>.class</tt> files exist</li>
    </ul></td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>groovy=&lang;version&rang;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

Any JAR files found in the application are automatically added to the classpath at runtime.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The container can be configured by modifying the [`config/groovy.yml`][] file in the buildpack fork.  The container uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Groovy repository index ([details][repositories]).
| `version` | The version of Groovy to use. Candidate versions can be found in [this listing][].

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/groovy.yml`]: ../config/groovy.yml
[repositories]: extending-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/groovy/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
