# Repositories
Many components need to have access to multiple versions of binaries.  The buildpack provides a `Repository` abstraction to encapsulate version resolution and download URI creation.

## Repository Structure
The repository is an HTTP-accessible collection of files.  The repository root must contain an `index.yml` file ([example][]) that is a mapping of concrete versions to absolute URIs consisting of a series of lines of the form:
```yaml
<version>: <URI>
```

The collection of files may be stored alongside the index file or elsewhere.

An example filesystem might look like:

```
/index.yml
/openjdk-1.6.0_27.tar.gz
/openjdk-1.7.0_21.tar.gz
/openjdk-1.8.0_M7.tar.gz
```

## Usage
The main class used when dealing with a repository is [`JavaBuildpack::Repository::ConfiguredItem`][].  It provides a single method that is used to resolve a specific version and its URI.

```ruby
# Finds an instance of the file based on the configuration and wraps any exceptions
# to identify the component.
#
# @param [String] component_name the name of the component
# @param [Hash] configuration the configuration
# @option configuration [String] :repository_root the root directory of the repository
# @option configuration [String] :version the version of the file to resolve
# @param [Block, nil] version_validator an optional version validation block
# @return [String] the URI of the chosen version of the file
# @return [JavaBuildpack::Util::TokenizedVersion] the chosen version of the file
def find_item(component_name, configuration)
```

Usage of the class might look like the following:

```ruby
version, uri = JavaBuildpack::Repository::ConfiguredItem.find_item(configuration)
```

or with version validation:

```ruby
version, uri = JavaBuildpack::Repository::ConfiguredItem.find_item(configuration) do |version|
  validate_version version
end
```

## Wildcards
`repository_root` declarations in component configuration files can have variables in them.  These variables are replaced by the repository infrastructure and the resulting URI is used when retrieving the repository index.

| Variable | Description |
| -------- | ----------- |
| `{default.repository.root}` | The common root for all repositories.  Currently defaults to `https://java-buildpack.cloudfoundry.org`.
| `{platform}` | The platform that the application is running on.  Currently detects `bionic`.
| `{architecture}` | The architecture of the system as returned by Ruby.  The value is typically one of `x86_64` or `x86`.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

Repositories can be configured by modifying the [`config/repository.yml`][] file in the buildpack fork.

| Name | Description
| ---- | -----------
| `default_repository_root` | This property can take a URI that is used as a common root for all of the repositories used by the buildpack.  The value is substituted for the `{default.repository.root}` variable in `repository_root` declarations.

## Proxies
Access to repositories may be affected by the existence of network proxies.  In order to configure the buildpack to use a proxy, set the `http_proxy`, `HTTP_PROXY`, `https_proxy`, or `HTTPS_PROXY` environment variables with the property proxy URI.  Proxy authentication crendentials can be embedded in the URI if needed.

```bash
cf set-env <APP_NAME> http_proxy http://username:password@host:port
```

## Version Syntax and Ordering
Versions are composed of major, minor, micro, and optional qualifier parts (`<major>.<minor>.<micro>[_<qualifier>]`).  The major, minor, and micro parts must be numeric.  The qualifier part is composed of letters, digits, and hyphens.  The lexical ordering of the qualifier is:

1. hyphen
2. lowercase letters
3. uppercase letters
4. digits

## Version Wildcards
In addition to declaring a specific versions to use, you can also specify a bounded range of versions to use.  Appending the `+` symbol to a version prefix chooses the latest version that begins with the prefix.

| Example | Description
| ------- | -----------
| `1.+`   	| Selects the greatest available version less than `2.0.0`.
| `1.7.+` 	| Selects the greatest available version less than `1.8.0`.
| `1.7.0_+` | Selects the greatest available version less than `1.7.1`. Use this syntax to stay up to date with the latest security releases in a particular version.


[`config/repository.yml`]: ../config/repository.yml
[`JavaBuildpack::Repository::ConfiguredItem`]: ../lib/java_buildpack/repository/configured_item.rb
[Configuration and Extension]: ../README.md#configuration-and-extension
[example]: https://java-buildpack.cloudfoundry.org/openjdk/bionic/x86_64/index.yml

