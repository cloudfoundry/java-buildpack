# Java Main Class Container
The Java Main Class Container allows applications that provide a class with a `main()` method in it to be run.  These applications are run with a command that looks like `./java/bin/java -cp . com.gopivotal.SampleClass`.

| Detection ||
| --- | ---
| **Criteria** | `Main-Class` attribute set in `META-INF/MANIFEST.MF` or `java_main_class` set
| **Tags** | `java-main`

## Configuration
The container can be configured by modifying the [`config/main.yml`][main_yml] file.

[main_yml]: ../config/main.yml

| Name | Description
| ---- | -----------
| `java_main_class` | The Java class name to run. Values containing whitespace are rejected with an error, but all others values appear without modification on the Java command line.  If not specified, the Java Manifest value of `Main-Class` is used.


