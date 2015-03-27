# `JavaBuildpack::Component::Application`
The `Application` is a read-only abstraction that exposes information about the Cloud Foundry application that is being staged.  In Cloud Foundry terminology, an application encapsulates not only the files that the user uploads, but also the environment and services that the user has configured.  Each of these things is exposed by the `Application` abstraction.

```ruby
# @!attribute [r] details
#   @return [Hash] the parsed contents of the +VCAP_APPLICATION+ environment variable
attr_reader :details

# @!attribute [r] environment
#   @return [Hash] all environment variables except +VCAP_APPLICATION+ and +VCAP_SERVICES+.  Those values are
#                  available separately in parsed form.
attr_reader :environment

# @!attribute [r] root
#   @return [JavaBuildpack::Util::FilteringPathname] the root of the application's fileystem filtered so that it
#                                                    only shows files that have been uploaded by the user
attr_reader :root

# @!attribute [r] services
#   @return [Hash] the parsed contents of the +VCAP_SERVICES+ environment variable
attr_reader :services
```

## `details`
This is the contents of the `VCAP_APPLICATION` environment variable parsed into a `Hash`.

## `environment`
This is the contents of all of the exposed environment variables except `VCAP_APPLICATION` and `VCAP_SERVICES`.  These values are exposed via `details` and `services` respectively.

## `root`
The root of the filesystem as uploaded by the user.  This is a `JavaBuildpack::Util::FilteringPathname` to ensure that this view of the filesystem remains uncorrupted by the actions of other components.  It can be safely assumed that other `Pathname`s based on this `root` will accurately reflect filesystem attributes (e.g. existence) before staging begins.

## `services`
A helper type (`JavaBuildpack::Component::Services`) that enables querying of the information exposed via `VCAP_SERVICES`

```ruby
# Compares the name, label, and tags of each service to the given +filter+.  The method returns +true+ if the
# +filter+ matches exactly one service, +false+ otherwise.
#
# @param [Regexp, String] filter a +RegExp+ or +String+ to match against the name, label, and tags of the services
# @param [String] required_credentials an optional list of keys or groups of keys, where at least one key from the
#                                      group, must exist in the credentials payload of the candidate service
# @return [Boolean] +true+ if the +filter+ matches exactly one service with the required credentials, +false+
#                   otherwise.
def one_service?(filter, *required_credentials)

# Compares the name, label, and tags of each service to the given +filter+.  The method returns the first service
# that the +filter+ matches.  If no service matches, returns +nil+
#
# @param [Regexp, String] filter a +RegExp+ or +String+ to match against the name, label, and tags of the services
# @return [Hash, nil] the first service that +filter+ matches.  If no service matches, returns +nil+.
def find_service(filter)
```
