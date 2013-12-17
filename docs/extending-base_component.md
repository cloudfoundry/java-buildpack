# `JavaBuildpack::Component::BaseComponent`
This base class is recommended for use by all components.  It exposes the name of the component and maps the contents of the context to instance variables.

## Required Method Implementations

```ruby
# If the component should be used when staging an application
#
# @return [Array<String>, String, nil] If the component should be used when staging the application, a +String+ or
#                                      an +Array<String>+ that uniquely identifies the component (e.g.
#                                      +open_jdk=1.7.0_40+).  Otherwise, +nil+.
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
#                        components are expected to return the command required to run the application.
def release
```

## Exposed Instance Variables

| Name | Type
| ---- | ----
| `@application` | [`JavaBuildpack::Component::Application`][]
| `@component_name` | `String`
| `@configuration` | `Hash`
| `@droplet` | [`JavaBuildpack::Component::Droplet`][]

## Helper Methods

```ruby
# Downloads an item with the given name and version from the given URI, then yields the resultant file to the given
# block.
#
# @param [JavaBuildpack::Util::TokenizedVersion] version
# @param [String] uri
# @param [String] name an optional name for the download.  Defaults to +@component_name+.
# @return [void]
def download(version, uri, name = @component_name, &block)

# Downloads a given JAR file and stores it.
#
# @param [String] version the version of the download
# @param [String] uri the uri of the download
# @param [String] jar_name the name to save the jar as
# @param [Pathname] target_directory the directory to store the JAR file in.  Defaults to the component's sandbox.
# @param [String] name an optional name for the download.  Defaults to +@component_name+.
def download_jar(version, uri, jar_name, target_directory = @droplet.sandbox, name = @component_name)

# Downloads a given TAR file and expands it.
#
# @param [String] version the version of the download
# @param [String] uri the uri of the download
# @param [Pathname] target_directory the directory to expand the TAR file to.  Defaults to the component's sandbox.
# @param [String] name an optional name for the download and expansion.  Defaults to +@component_name+.
def download_tar(version, uri, target_directory = @droplet.sandbox, name = @component_name)

# Downloads a given ZIP file and expands it.
#
# @param [Boolean] strip_top_level whether to strip the top-level directory when expanding. Defaults to +true+.
# @param [Pathname] target_directory the directory to expand the ZIP file to.  Defaults to the component's sandbox.
# @param [String] name an optional name for the download.  Defaults to +@component_name+.
def download_zip(version, uri, strip_top_level = true, target_directory = @droplet.sandbox, name = @component_name)

# Wrap the execution of a block with timing information
#
# @param [String] caption the caption to print when timing starts
def with_timing(caption)
```

[`JavaBuildpack::Component::Application`]: extending-application.md
[`JavaBuildpack::Component::Droplet`]: extending-droplet.md
