# OpenJDK JRE
The OpenJDK JRE provides Java runtimes from the [OpenJDK][] project.  Versions of Java from the `1.6`, `1.7`, and `1.8` lines are available.  Unless otherwise configured, the version of Java that will be used is specified in [`config/openjdk.yml`][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Unconditional</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>openjdk-&lang;version&rang;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The JRE can be configured by modifying the [`config/openjdk.yml`][] file.  The JRE uses the [`Repository` utility support][repositories] and so it supports the [version syntax][]  defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the OpenJDK repository index ([details][repositories]).
| `version` | The version of Java runtime to use.  Candidate versions can be found in [this listing][].
| `memory_sizes` | Optional memory sizes, described below under "Memory".
| `memory_heuristics` | Default memory size proportions, described below under "Default Memory Sizes".

### Memory

The following optional properties may be specified in the `memory_sizes` mapping.

| Name | Description
| ---- | -----------
| `heap` | The Java maximum heap size to use. For example, a value of `64m` will result in the Java command line option `-Xmx64m`. Values containing whitespace are rejected with an error, but all others values appear without modification on the Java command line appended to `-Xmx`.
| `metaspace` | The Java maximum Metaspace size to use. This is applicable to versions of OpenJDK from 1.8 onwards. For example, a value of `128m` will result in the Java command line option `-XX:MaxMetaspaceSize=128m`. Values containing whitespace are rejected with an error, but all others values appear without modification on the Java command line appended to `-XX:MaxMetaspaceSize=`.
| `permgen` | The Java maximum PermGen size to use. This is applicable to versions of OpenJDK earlier than 1.8. For example, a value of `128m` will result in the Java command line option `-XX:MaxPermSize=128m`. Values containing whitespace are rejected with an error, but all others values appear without modification on the Java command line appended to `-XX:MaxPermSize=`.
| `stack` | The Java stack size to use. For example, a value of `256k` will result in the Java command line option `-Xss256k`. Values containing whitespace are rejected with an error, but all others values appear without modification on the Java command line appended to `-Xss`.

### Default Memory Sizes

If some memory sizes are not specified using the above properties, default values are provided. For maximum heap, Metaspace, or PermGen size, the default value is based on a proportion of the total memory specified when the application was pushed. For stack size, the default value is one megabyte.

If a memory size is specified which is not equal to the default value, the other default values are adjusted proportionately, except that the default stack size is never adjusted.

The default memory size proportions are configured in the `memory_heuristics` mapping of [`config/openjdk.yml`][]. Each memory size is given a weighting between `0` and `1` corresponding to a proportion of the total memory specified when the application was pushed. The weightings should add up to `1`.

[Configuration and Extension]: ../README.md#Configuration-and-Extension
[`config/openjdk.yml`]: ../config/openjdk.yml
[OpenJDK]: http://openjdk.java.net
[repositories]: util-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/openjdk/lucid/x86_64/index.yml
[version syntax]: util-repositories.md#version-syntax-and-ordering
