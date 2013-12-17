# Caches
Many components will want to cache large files that are downloaded for applications.  The buildpack provides a cache abstraction to encapsulate this caching behavior.  The cache abstraction is comprised of three cache types each with the same signature.

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
# @return [void]
def get(uri)

# Remove an item from the cache
#
# @param [String] uri the URI of the item to remove
# @return [void]
def evict(uri)
```

Usage of a cache might look like the following:

```ruby
JavaBuildpack::Util::DownloadCache.new().get(uri) do |file|
  YAML.load_file(file)
end
```

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

Caching can be configured by modifying the [`config/cache.yml`][] file.

| Name | Description
| ---- | -----------
| `remote_downloads` | This property can take the value `enabled` or `disabled`. <p>The default value of `enabled` means that the buildpack will check the internet connection and remember the result for the remainder of the buildpack invocation. If the internet is available, it will then be used to download files. If the internet is not available, cache will be consulted instead. <p>Alternatively, the property may be set to `disabled` which avoids the check for an internet connection, does not attempt downloads, and consults the cache instead.

## `JavaBuildpack::Util::Cache::DownloadCache`
The [`DownloadCache`][] is the most generic of the three caches.  It allows you to create a cache that persists files any that write access is available.  The constructor signature looks the following:

```ruby
# Creates an instance of the cache that is backed by the filesystem rooted at +cache_root+
#
# @param [String] cache_root the filesystem root for downloaded files to be cached in
def initialize(cache_root = Dir.tmpdir)
```

## `JavaBuildpack::Util::Cache::ApplicationCache`
The [`ApplicationCache`][] is a cache that persists files into the application cache passed to the `compile` script.  It examines `ARGV[1]` for the cache location and configures itself accordingly.

```ruby
# Creates an instance that is configured to use the application cache.  The application cache location is defined by
# the second argument (<tt>ARGV[1]</tt>) to the +compile+ script.
#
# @raise if the second argument (<tt>ARGV[1]</tt>) to the +compile+ script is +nil+
def initialize
```

## `JavaBuildpack::Util::Cache::GlobalCache`
The [`GlobalCache`][] is a cache that persists files into the global cache passed to all scripts.  It examines `ENV['BUILDPACK_CACHE']` for the cache location and configures itself accordingly.

```ruby
# Creates an instance that is configured to use the global cache.  The global cache location is defined by the
# +BUILDPACK_CACHE+ environment variable
#
# @raise if the +BUILDPACK_CACHE+ environment variable is +nil+
def initialize
```

[`ApplicationCache`]: ../lib/java_buildpack/util/cache/application_cache.rb
[`config/cache.yml`]: ../config/cache.yml
[`DownloadCache`]: ../lib/java_buildpack/util/cache/download_cache.rb
[`GlobalCache`]: ../lib/java_buildpack/util/cache/global_cache.rb
[Configuration and Extension]: ../README.md#Configuration-and-Extension
