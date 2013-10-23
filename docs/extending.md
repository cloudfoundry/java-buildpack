# Extending
To add a component, its class file must be put in a specific location and the class name added to [`config/components.yml`][].

| Component Type | Location
| -------------- | --------
| Container | [`lib/java_buildpack/container`][]
| Framework | [`lib/java_buildpack/framework`][]
| JRE | [`lib/java_buildpack/jre`][]


## Component Class Contract
Each component class must satisfy a contract defined by the following methods:

```ruby
# If the component should be used when staging an application
#
# @return [Array<String>, String, nil] If the component should be used when staging the application, a +String+ or
#                                      an +Array<String>+ that uniquely identifies the component (e.g.
#                                      +openjdk-1.7.0_40+).  Otherwise, +nil+.
def detect

# Modifies the application's file system.  The component is expected to transform the application's file system in
# whatever way is necessary (e.g. downloading files or creating symbolic links) to support the function of the
# component.  Status output written to +STDOUT+ is expected as part of this invocation.
#
# @return [void]
def compile

# Modifies the application's runtime configuration. The component is expected to transform members of the +context+
# (e.g. +@java_home+, +@java_opts+, etc.) in whatever way is necessary to support the function of the component.
#
# Container components are also expected to create the command required to run the application.  These components
# are expected to read the +context+ values and take them into account when creating the command.
#
# @return [void, String] components other than containers are not expected to return any value.  Container
#                        compoonents are expected to return the command required to run the application.
def release
```


## Component Context
Each component class must have an `initialize` method that takes a `Hash` containg contextual information about the application.  It is this "whiteboard" that is used by the components to communicate with one another.  The context contains the following entries:

| Name | Type | Description
| ---- | ---- | -----------
| `app_dir` | `String` | The directory that the application exists in
| `application` | [`JavaBuildpack::Application`][] | An abstraction around the application
| `configuration` | `Hash` | The component configuration provided by the user via `config/<component-name>.yml`
| `environment` | `Hash` | A hash containing all environment variables except `VCAP_APPLICATION` and `VCAP_SERVICES`.  Those values are available separately in parsed form.
| `java_home` | `String` | The directory that acts as `JAVA_HOME`
| `java_opts` | `Array<String>` | An array that Java options can be added to
| `lib_directory` | `String` | The directory that additional libraries are placed in
| `vcap_application` | `Hash` | The contents of the `VCAP_APPLICATION` environment variable
| `vcap_services` | `Hash` | The contents of the `VCAP_SERVICES` environment variable


## Base Classes
The buildpack provides a collection of base classes that may help you implement a component.

### [`lib/java_buildpack/base_component.rb`][]
This base class is recommended for use by all components.  It ensures that each component has a name, that the context is available at `@context` and that each key in the `context` is exposed as an instance variable (e.g. `context[:java_home]` is available as `@java_home`).  In addition it provides two helper methods for downloading files as part of the component's operation.

### [`lib/java_buildpack/versioned_dependency_component.rb`][]
This base class is recommended for use by any component that uses the buildpack [repository support][] to download a dependency.  It ensures that each component has a `@version` and `@uri` that were resolved from the repository specified in the component's configuration.  It also implements the `detect` method with an standard implementation.

[`config/components.yml`]: ../config/components.yml
[`JavaBuildpack::Application`]: ../lib/java_buildpack/application.rb
[`lib/java_buildpack/base_component.rb`]: ../lib/java_buildpack/base_component.rb
[`lib/java_buildpack/container`]: ../lib/java_buildpack/container
[`lib/java_buildpack/framework`]: ../lib/java_buildpack/framework
[`lib/java_buildpack/jre`]: ../lib/java_buildpack/jre
[`lib/java_buildpack/versioned_dependency_component.rb`]: ../lib/java_buildpack/versioned_dependency_component.rb
[repository support]: util-repositories.md
