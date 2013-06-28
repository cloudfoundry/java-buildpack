# `JAVA_OPTS` Framework
The `JAVA_OPTS` Framework contributes arbitrary Java options to the application at runtime.
	
<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td><ptt>java_opts</tt> set</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>java-opts</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script
	

## Configuration
The framework can be configured by modifying the [`config/java_opts.yml`][java_opts_yml] file.

[java_opts_yml]: ../config/java_opts.yml

| Name | Description
| ---- | -----------
| `java_opts` | The Java options to use when running the application.  All values are used without modification when invoking the JVM. The options should be specified as a single string enclosed in double quotes, e.g. "-Xcheck:jni -Xfuture".
