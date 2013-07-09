# Extending Frameworks
To add a framework, the class file must be located in [`lib/java_buildpack/framework`][framework_dir] and the class name added to [`config/components.yml`][components_yml].  The class must have the following methods:

[framework_dir]: ../lib/java_buildpack/framework
[components_yml]: ../config/components.yml

```ruby
# An initializer for the instance.
#
# @param [Hash<Symbol, String>] context A shared context provided to all components
# @option context [String] :app_dir the directory that the application exists in
# @option context [String] :java_home the directory that acts as +JAVA_HOME+
# @option context [Array<String>] :java_opts an array that Java options can be added to
# @option context [String] :lib_directory the directory that additional libraries are placed in
# @option context [Hash] :configuration the configuration provided by the user
def initialize(context)

# Determines if the framework can be applied to the application
#
# @return [Array<String>, String, nil] If the framework can be used to run the application, a +String+ or an
#                                      +Array<String>+ that uniquely identifies the framework (e.g. +java-opts+).
#                                      Otherwise, +nil+.
def detect

# Transforms the application based on the framework.  Status output written to +STDOUT+ is expected as part of this
# invocation.
#
# @return [void]
def compile

# Adds any framework-specific options to +context[:java_opts]+.  Typically this includes any JRE configuration required
# by the framework, but could be anything that a framework needs to have configured.
#
# @return [void]
def release
```
