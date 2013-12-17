# Other Utiltities
The buildpack provides a number of other utilities that may help in implementing components.

## [`JavaBuildpack::Util::ClassFileUtils`][]
The `ClassFileUtils` class provides a method for getting all of the class files in an application.

## [`JavaBuildpack::Util::ConfigurationUtils`][]
The `ConfigurationUtils` class provides a method for getting the parsed contents of a configuration file from the buildpack configuration directory.

## [`JavaBuildpack::Util::GroovyUtils`][]
The `GroovyUtils` class provides a set of methods for finding groovy files and determing if they are of any special kind (e.g. they have a main method, they are a pogo, etc.).

## [`JavaBuildpack::Util::JavaMainUtils`][]
The `JavaMainUtils` class provides a a set of methods for determining the Java main class of an application if it exists.

## [`JavaBuildpack::Util::Properties`][]
The `Properties` class provides a Ruby class that can read in a Java properties file and acts as a `Hash` with that data.

## [`JavaBuildpack::Util::Shell`][]
The `shell` method encapsulates a standard shell invocation in the buildpack.  It ensures that the output of the command is suppressed unless the command fails.  When that happens, the content of `stdout` and `stderr` are printed.  This method is mixed into the `BaseComponent` class and all of its subclasses.


[`JavaBuildpack::Util::ClassFileUtils`]: ../lib/java_buildpack/util/class_file_utils.rb
[`JavaBuildpack::Util::ConfigurationUtils`]: ../lib/java_buildpack/util/configuration_utils.rb
[`JavaBuildpack::Util::GroovyUtils`]: ../lib/java_buildpack/util/groovy_utils.rb
[`JavaBuildpack::Util::JavaMainUtils`]: ../lib/java_buildpack/util/java_main_utils.rb
[`JavaBuildpack::Util::Properties`]: ../lib/java_buildpack/util/properties.rb
[`JavaBuildpack::Util::Shell`]: ../lib/java_buildpack/util/shell.rb
