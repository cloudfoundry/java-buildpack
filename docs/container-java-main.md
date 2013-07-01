# Java Main Class Container
The Java Main Class Container allows an application that provides a class with a `main()` method to be run.  The application is executed with a command of the form:

    ./java/bin/java -cp . com.gopivotal.SampleClass

Command line arguments may optionally be configured.

<table>
  <tr>
    <td><strong>Detection Criteria</strong></td><td><tt>Main-Class</tt> attribute set in <tt>META-INF/MANIFEST.MF</tt> or <tt>java_main_class</tt> set in [`config/main.yml`][main_yml]</td>
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
| `arguments` | Optional command line arguments to be passed to the Java main class. The arguments are specified as a single YAML scalar in plain style or enclosed in single or double quotes.
| `java_main_class` | The Java class name to run. Values containing whitespace are rejected with an error, but all others values appear without modification on the Java command line.  If not specified, the Java Manifest value of `Main-Class` is used.


