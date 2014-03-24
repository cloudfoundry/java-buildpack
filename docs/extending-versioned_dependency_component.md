# `JavaBuildpack::Component::VersionedDependencyComponent`
This base class is recommended for use by any component that uses the buildpack [repository support][] to download a dependency.  It ensures that each component has a `@version` and `@uri` that were resolved from the repository specified in the component's configuration.  It also implements the `detect` method with a standard implementation.

## Required Method Implementations

```ruby
# Modifies the application's file system.  The component is expected to transform the application's file system in
# whatever way is necessary (e.g. downloading files or creating symbolic links) to support the function of the
# component.  Status output written to +STDOUT+ is expected as part of this invocation.
#
# @return [Void]
def compile

# Modifies the application's runtime configuration. The component is expected to transform members of the +context+
# (e.g. +@java_home+, +@java_opts+, etc.) in whatever way is necessary to support the function of the component.
#
# Container components are also expected to create the command required to run the application.  These components
# are expected to read the +context+ values and take them into account when creating the command.
#
# @return [void, String] components other than containers are not expected to return any value.  Container
#                        components are expected to return the command required to run the application.
def release

# Whether or not this component supports this application
#
# @return [Boolean] whether or not this component supports this application
def supports?
```

## Exposed Instance Variables

| Name | Type
| ---- | ----
| `@application` | [`JavaBuildpack::Component::Application`][]
| `@component_name` | `String`
| `@configuration` | `Hash`
| `@droplet` | [`JavaBuildpack::Component::Droplet`][]
| `@uri` | `String`
| `@version` | `JavaBuildpack::Util::TokenizedVersion`


## Helper Methods

```ruby
# Downloads an item with the given name and version from the given URI, then yields the resultant file to the given
# block.
#
# @param [JavaBuildpack::Util::TokenizedVersion] version
# @param [String] uri
# @param [String] name an optional name for the download.  Defaults to +@component_name+.
# @return [Void]
def download(version, uri, name = @component_name, &block)

# Downloads a given JAR file and stores it.
#
# @param [String] jar_name the name to save the jar as
# @param [Pathname] target_directory the directory to store the JAR file in.  Defaults to the component's sandbox.
# @param [String] name an optional name for the download.  Defaults to +@component_name+.
def download_jar(jar_name = jar_name, target_directory = @droplet.sandbox, name = @component_name)

# Downloads a given TAR file and expands it.
#
# @param [Pathname] target_directory the directory to expand the TAR file to.  Defaults to the component's sandbox.
# @param [String] name an optional name for the download and expansion.  Defaults to +@component_name+.
def download_tar(target_directory = @droplet.sandbox, name = @component_name)

# Downloads a given ZIP file and expands it.
#
# @param [Boolean] strip_top_level whether to strip the top-level directory when expanding. Defaults to +true+.
# @param [Pathname] target_directory the directory to expand the ZIP file to.  Defaults to the component's sandbox.
# @param [String] name an optional name for the download.  Defaults to +@component_name+.
def download_zip(strip_top_level = true, target_directory = @droplet.sandbox, name = @component_name)

# A generated JAR name for the component.  Meets the format +<component-id>-<version>.jar+
def jar_name

# Wrap the execution of a block with timing information
#
# @param [String] caption the caption to print when timing starts
def with_timing(caption)
```

[`JavaBuildpack::Component::Application`]: extending-application.md
[`JavaBuildpack::Component::Droplet`]: extending-droplet.md
[repository support]: extending-repositories.md
