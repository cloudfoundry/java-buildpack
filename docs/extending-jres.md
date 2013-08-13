# JREs
To add a JRE, the class file must be located in [`lib/java_buildpack/jre`][] and the class name added to [`config/components.yml`][].  The class must have the following methods:

```ruby
# An initializer for the instance.
#
# @param [Hash<Symbol, String>] context A shared context provided to all components
# @option context [String] :app_dir the directory that the application exists in
# @option context [Hash] :environment A hash containing all environment variables except +VCAP_APPLICATION+ and
#                                     +VCAP_SERVICES+.  Those values are available separately in parsed form.
# @option context [String] :java_home the directory that acts as +JAVA_HOME+
# @option context [Array<String>] :java_opts an array that Java options can be added to
# @option context [String] :lib_directory the directory that additional libraries are placed in
# @option context [Hash] :vcap_application The contents of the +VCAP_APPLICATION+ environment variable
# @option context [Hash] :vcap_services The contents of the +VCAP_SERVICES+ environment variable
# @option context [Hash] :configuration the configuration provided by the user
def initialize(context)

# Determines if the JRE can be used to run the application.
#
# @return [Array<String>, String, nil] If the JRE can be used to run the application, a +String+ or an +Array<String>+
#                                      that uniquely identifies the JRE (e.g. +openjdk-1.7.0_21+).  Otherwise, +nil+.
def detect

# Downloads and unpacks the JRE.  Status output written to +STDOUT+ is expected as part of this invocation.
#
# @return [void]
def compile

# Adds any JRE-specific options to +context[:java_opts]+.  Typically this includes memory configuration (heap, perm gen,
# etc.) but could be anything that a JRE needs to have configured.  As well, +context[:java_home]+ is expected to be
# updated with the value that the JRE has been unpacked to.  This must be done using the {String.concat} method to
# ensure that the value is accessible to other components.
#
# @return [void]
def release
```

[`config/components.yml`]: ../config/components.yml
[`lib/java_buildpack/jre`]: ../lib/java_buildpack/jre
