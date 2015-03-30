# `JavaBuildpack::Component::ModularComponent`
This base class is recommended for use by any component that is sufficiently complex to need modularization.  It enables a component to be composed of multiple "sub-components" and coordinates the component lifecycle across all of them.

## Required Method Implementations

```ruby
# The command for this component
#
# @return [void, String] components other than containers are not expected to return any value.  Container
#                        components are expected to return the command required to run the application.
def command

# The sub_components that make up this component
#
# @param [Hash] context the context of the component
# @return [Array<BaseComponent>] a collection of +BaseComponent+s that make up the sub_components of this
#                                component
def sub_components(_context)

# Whether or not this component supports this application
#
# @return [Boolean] whether or not this component supports this application
def supports?
```

## Exposed Instance Variables

| Name | Type
| ---- | ----
| `@modules` | [`Array<JavaBuildpack::Component::BaseComponent>`][]


## Helper Methods

```ruby
# Returns a copy of the context, but with a subset of the original configuration
#
# @param [Hash] context the original context of the component
# @param [String] key the key to get a subset of the context from
# @return [Hash] context a copy of the original context, but with a subset of the original configuration
def sub_configuration_context(context, key)
```

[`Array<JavaBuildpack::Component::BaseComponent>`]: extending-base_component.md
