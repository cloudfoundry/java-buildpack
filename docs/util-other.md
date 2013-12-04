# Other Utiltities
The buildpack provides a number of other utilities that may help in implementing components.

## [`JavaBuildpack::Util::GroovyUtils`][]
The `GroovyUtils` class provides a set of methods for finding groovy files and determing if they are of any special kind (e.g. they have a main method, they are a pogo, etc.).

## [`JavaBuildpack::Util::Properties`][]
The `Properties` class provides a Ruby class that can read in a Java properties file and acts as a `Hash` with that data.

## [`JavaBuildpack::Util::ServiceUtils`][]
The `ServiceUtils` class provides a set of methods for finding a given service in the `VCAP_SERVICES` payload.

[`JavaBuildpack::Util::GroovyUtils`]: ../lib/java_buildpack/util/groovy_utils.rb
[`JavaBuildpack::Util::Properties`]: ../lib/java_buildpack/util/properties.rb
[`JavaBuildpack::Util::ServiceUtils`]: ../lib/java_buildpack/util/service_utils.rb
