# `JavaBuildpack::Component::Droplet`
The `Droplet` is a read-write abstraction that exposes information about the Cloud Foundry droplet that is being created.  In Cloud Foundry terminology, a droplet encapsulates the filesystem and runtime configuration that will be run.  Each of these things is exposed by the `Droplet` abstraction.

```ruby
# @!attribute [r] additional_libraries
#   @return [AdditionalLibraries] the shared +AdditionalLibraries+ instance for all components
attr_reader :additional_libraries

# @!attribute [r] component_id
#   @return [String] the id of component using this droplet
attr_reader :component_id

# @!attribute [r] java_home
#   @return [ImmutableJavaHome, MutableJavaHome] the shared +JavaHome+ instance for all components.  If the
#                                                component using this instance is a jre, then this will be an
#                                                instance of +MutableJavaHome+.  Otherwise it will be an instance of
#                                                +ImmutableJavaHome+.
attr_reader :java_home

# @!attribute [r] java_opts
#   @return [JavaOpts] the shared +JavaOpts+ instance for all components
attr_reader :java_opts

# @!attribute [r] root
#   @return [JavaBuildpack::Util::FilteringPathname] the root of the droplet's fileystem filtered so that it
#                                                    excludes files in the sandboxes of other components
attr_reader :root

# @!attribute [r] sandbox
#   @return [Pathname] the root of the component's sandbox
attr_reader :sandbox

# Copy resources from a components resources directory to a directory
#
# @param [Pathname] target_directory the directory to copy to.  Default to a component's +sandbox+
def copy_resources(target_directory = @sandbox)
```

## `additional_libraries`
A helper type (`JavaBuildpack::Component::AdditionalLibraries`) that enables the addition of JARs to the classpath of the running droplet.

```ruby
# Returns the contents of the collection as a classpath formatted as +-cp <value1>:<value2>+
#
# @return [String] the contents of the collection as a classpath
def as_classpath

# Symlink the contents of the collection to a destination directory.
#
# @param [Pathname] destination the destination to link to
def link_to(destination)
```

## `component_id`
The id of the component, as determined by the buildpack.  This is used in various locations and is exposed to ensure uniformity of the value.

## `java_home`
One of two helper types (`JavaBuildpack::Component::ImmutableJavaHome`, `JavaBuildpack::Component::MutableJavaHome`) that enables the mutation and retrieval of the droplet's `JAVA_HOME`.  Components that are JREs will be given the `MutableJavaHome` in order to set the value.  All other components will be given the `ImmutableJavaHome` in order to retrieve the value.

```ruby
# Returns the path of +JAVA_HOME+ as an environment variable formatted as +JAVA_HOME="$PWD/<value>"+
#
# @return [String] the path of +JAVA_HOME+ as an environment variable
def as_env_var

# Execute a block with the +JAVA_HOME+ environment variable set
#
# @yield yields to block with the +JAVA_HOME+ environment variable set
def do_with

# @return [String] the root of the droplet's +JAVA_HOME+
def root

# Sets the root of the droplet's +JAVA_HOME+
#
# @param [Pathname] value the root of the droplet's +JAVA_HOME+
def root=(value)
```

## `java_opts`
A helper type (`JavaBuildpack::Component::JavaOpts`) that enables the addition of values to +JAVA_OPTS+.  The `add_javaagent`, `add_system_property`, and `add_option` method all inspect that value to determine if it is a `Pathname`.  If it is, the value is converted so that it is relative to the root of the droplet.

```ruby
# Adds a +javaagent+ entry to the +JAVA_OPTS+.  Prepends +$PWD+ to the path (relative to the droplet root) to
# ensure that the path is always accurate.
#
# @param [Pathname] path the path to the +javaagent+ JAR
# @return [JavaOpts]     +self+ for chaining
def add_javaagent(path)

# Adds a system property to the +JAVA_OPTS+.  Ensures that the key is prepended with +-D+.  If the value is a
# +Pathname+, then prepends +$PWD+ to the path (relative to the droplet root) to ensure that the path is always
# accurate.  Otherwise, uses the value as-is.
#
# @param [String] key             the key of the system property
# @param [Pathname, String] value the value of the system property
# @return [JavaOpts]              +self+ for chaining
def add_system_property(key, value)

# Adds an option to the +JAVA_OPTS+.  Nothing is prepended to the key.  If the value is a +Pathname+, then prepends
# +$PWD+ to the path (relative to the droplet root) to ensure that the path is always accurate.  Otherwise, uses
# the value as-is.
#
# @param [String] key             the key of the option
# @param [Pathname, String] value the value of the system property
# @return [JavaOpts]              +self+ for chaining
def add_option(key, value)

# Returns the contents as an environment variable formatted as +JAVA_OPTS="<value1> <value2>"+
#
# @return [String] the contents as an environment variable
def as_env_var
```

## `root`
The root of the filesystem for the droplet.  This is a `JavaBuildpack::Util::FilteringPathname` to ensure that this view of the filesystem includes _only_ the users's code and the files in the component's sandbox.  It can be safely assumed that other `Pathname`s based on this `root` will accurately reflect filesystem attributes for those files.

## `sandbox`
The root of the filesystem for the component's sandbox.  The sandbox is a portion of the filesystem that a component can work in that is isolated from all other components.  This is a `JavaBuildpack::Util::FilteringPathname` to ensure that this view of the filesystem includes _only_ the the component's sandbox.  It can be safely assumed that other `Pathname`s based on this `sandbox` will accurately reflect filesystem attributes for those files.

## `copy_resources()`
Copy the contents of the component's resources directory if it exists.  The components resources directory is found in the `<buildpack-root>/resources/<component-id>`.  This is typically used to overlay the contents of the resources directory onto a component's sandbox.
