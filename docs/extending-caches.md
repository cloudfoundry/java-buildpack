# Caches
Many components will want to cache large files that are downloaded for applications.  The buildpack provides a cache abstraction to encapsulate this caching behavior.  The cache abstraction is comprised of two cache types each with the same signature.

```ruby
# Retrieves an item from the cache.  Retrieval of the item uses the following algorithm:
#
# 1. Obtain an exclusive lock based on the URI of the item. This allows concurrency for different items, but not for
#    the same item.
# 2. If the the cached item does not exist, download from +uri+ and cache it, its +Etag+, and its +Last-Modified+
#    values if they exist.
# 3. If the cached file does exist, and the original download had an +Etag+ or a +Last-Modified+ value, attempt to
#    download from +uri+ again.  If the result is +304+ (+Not-Modified+), then proceed without changing the cached
#    item.  If it is anything else, overwrite the cached file and its +Etag+ and +Last-Modified+ values if they exist.
# 4. Downgrade the lock to a shared lock as no further mutation of the cache is possible.  This allows concurrency for
#    read access of the item.
# 5. Yield the cached file (opened read-only) to the passed in block. Once the block is complete, the file is closed
#    and the lock is released.
#
# @param [String] uri the uri to download if the item is not already in the cache.  Also used in the case where the
#                     item is already in the cache, to validate that the item is up to date
# @yieldparam [File] file the file representing the cached item. In order to ensure that the file is not changed or
#                    deleted while it is being used, the cached item can only be accessed as part of a block.
# @return [Void]
def get(uri)

# Remove an item from the cache
#
# @param [String] uri the URI of the item to remove
# @return [Void]
def evict(uri)
```

Usage of a cache might look like the following:

```ruby
JavaBuildpack::Util::DownloadCache.new().get(uri) do |file|
  YAML.load_file(file)
end
```

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

Caching can be configured by modifying the [`config/cache.yml`][] file in the buildpack fork.

| Name | Description
| ---- | -----------
| `remote_downloads` | This property can take the value `enabled` or `disabled`. <p>The default value of `enabled` means that the buildpack will check the internet connection and remember the result for the remainder of the buildpack invocation. If the internet is available, it will then be used to download files. If the internet is not available, cache will be consulted instead. <p>Alternatively, the property may be set to `disabled` which avoids the check for an internet connection, does not attempt downloads, and consults the cache instead.
| `client_authentication.certificate_location` | The path to a PEM or DER encoded certificate to use for SSL client certificate authentication
| `client_authentication.private_key_location` | The path to a PEM or DER encoded DSA or RSA private key to use for SSL client certificate authentication
| `client_authentication.private_key_password` | The password for the private key to use for SSL client certificate authentication

## `JavaBuildpack::Util::Cache::DownloadCache`
The [`DownloadCache`][] is the most generic of the two caches.  It allows you to create a cache that persists files any that write access is available.  The constructor signature looks the following:

```ruby
# Creates an instance of the cache that is backed by a number of filesystem locations.  The first argument
# (+mutable_cache_root+) is the only location that downloaded files will be stored in.
#
# @param [Pathname] mutable_cache_root the filesystem location in which find cached files in.  This will also be
#                                      the location that all downloaded files are written to.
# @param [Pathname] immutable_cache_roots other filesystem locations to find cached files in.  No files will be
#                                         written to these locations.
def initialize(mutable_cache_root = Pathname.new(Dir.tmpdir), *immutable_cache_roots)
```

## `JavaBuildpack::Util::Cache::ApplicationCache`
The [`ApplicationCache`][] is a cache that persists files into the application cache passed to the `compile` script.  It examines `ARGV[1]` for the cache location and configures itself accordingly.

```ruby
# Creates an instance of the cache that is backed by the the application cache
def initialize
```

[`ApplicationCache`]: ../lib/java_buildpack/util/cache/application_cache.rb
[`config/cache.yml`]: ../config/cache.yml
[`DownloadCache`]: ../lib/java_buildpack/util/cache/download_cache.rb
[Configuration and Extension]: ../README.md#configuration-and-extension
