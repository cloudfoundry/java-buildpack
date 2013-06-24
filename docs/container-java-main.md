# Java Main Class Container
The Java Main Class Container allows applications that provide a class with a `main()` method in it to be run.  These applications are run with a command that looks like `./java/bin/java -cp . com.gopivotal.SampleClass`.

<table>
  <tr>
    <td><strong>Detection Criteria</strong></td><td><tt>Main-Class</tt> attribute set in <tt>META-INF/MANIFEST.MF</tt> or <tt>java_main_class</tt> set</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>java-main</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
The container can be configured by modifying the [`config/main.yml`][main_yml] file.

[main_yml]: ../config/main.yml

| Name | Description
| ---- | -----------
| `java_main_class` | The Java class name to run. Values containing whitespace are rejected with an error, but all others values appear without modification on the Java command line.  If not specified, the Java Manifest value of `Main-Class` is used.


