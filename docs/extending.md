# Extending
For general information on extending the buildpack, refer to [Configuration and Extension](../README.md#configuration-and-extension).

To add a component, its class name must be added to [`config/components.yml`][].  It is recommended, but not required, that the class' file be placed in a directory that matches its type.

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
#                                      +open_jdk-1.7.0_40+).  Otherwise, +nil+.
def detect

# Modifies the application's file system.  The component is expected to transform the application's file system in
# whatever way is necessary (e.g. downloading files or creating symbolic links) to support the function of the
# component.  Status output written to +STDOUT+ is expected as part of this invocation.
#
# @return [Void]
def compile

# Modifies the application's runtime configuration. The component is expected to transform members of the +droplet+
# (e.g. +java_home+, +java_opts+, etc.) in whatever way is necessary to support the function of the component.
#
# Container components are also expected to create the command required to run the application.  These components
# are expected to read the +droplet+ values and take them into account when creating the command.
#
# @return [void, String] components other than containers are not expected to return any value.  Container
#                        compoonents are expected to return the command required to run the application.
def release
```

## Component Context
Each component class must have an `initialize` method that takes a `Hash` containing helper types for the application.  These helper types are the way that components to communicate with one another.  The context contains the following entries:

| Name | Type | Description
| ---- | ---- | -----------
| `application` | [`JavaBuildpack::Component::Application`][] | A read-only abstraction around the application
| `configuration` | `Hash` | The component configuration provided by the user via `config/<component-name>.yml`
| `droplet` | [`JavaBuildpack::Component::Droplet`][] | A read-write abstraction around the droplet


## Base Classes
The buildpack provides a collection of base classes that may help you implement a component.

### [`JavaBuildpack::Component::BaseComponent`][]
This base class is recommended for use by all components.  It ensures that each component has a name, and that the contents of the context are exposed as instance variables (e.g. `context[:application]` is available as `@application`).  In addition it provides two helper methods for downloading files as part of the component's operation.

### [`JavaBuildpack::Component::ModularComponent`][]
This base class is recommended for use by any component that is sufficiently complex to need modularization.  It enables a component to be composed of multiple "sub-components" and coordinates the component lifecycle across all of them.

### [`JavaBuildpack::Component::VersionedDependencyComponent`][]
This base class is recommended for use by any component that uses the buildpack [repository support][] to download a dependency.  It ensures that each component has a `@version` and `@uri` that were resolved from the repository specified in the component's configuration.  It also implements the `detect` method with a standard implementation.

## Examples
The following example components are relatively simple and good for copying as the basis for a new component.

### Java Main Class Container
The [Java Main Class Container](container-java_main.md) ([`lib/java_buildpack/container/java_main.rb`](../lib/java_buildpack/container/main.rb)) extends the [`JavaBuildpack::Component::BaseComponent`](../lib/java_buildpack/component/base_component.rb) base class described above.

### Tomcat Container
The [Tomcat Container](container-tomcat.md) ([`lib/java_buildpack/container/tomcat.rb`](../lib/java_buildpack/container/tomcat.rb)) extends the [`JavaBuildpack::Component::ModularComponent`](../lib/java_buildpack/component/modular_component.rb) base class described above.

### Spring Boot CLI Container
The [Spring Boot CLI Container](container-spring_boot_cli.md) ([`lib/java_buildpack/container/spring_boot_cli.rb`](../lib/java_buildpack/container/spring_boot_cli.rb)) extends the [`JavaBuildpack::Component::VersionedDependencyComponent`](../lib/java_buildpack/component/versioned_dependency_component.rb) base class described above.

[`config/components.yml`]: ../config/components.yml
[`JavaBuildpack::Component::Application`]: extending-application.md
[`JavaBuildpack::Component::BaseComponent`]: extending-base_component.md
[`JavaBuildpack::Component::Droplet`]: extending-droplet.md
[`JavaBuildpack::Component::ModularComponent`]: extending-modular_component.md
[`JavaBuildpack::Component::VersionedDependencyComponent`]: extending-versioned_dependency_component.md
[`lib/java_buildpack/container`]: ../lib/java_buildpack/container
[`lib/java_buildpack/framework`]: ../lib/java_buildpack/framework
[`lib/java_buildpack/jre`]: ../lib/java_buildpack/jre
[repository support]: extending-repositories.md


