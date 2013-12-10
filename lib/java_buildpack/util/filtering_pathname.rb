# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'java_buildpack/util'
require 'pathname'
require 'set'

module JavaBuildpack::Util

  # This class conforms to the interface of +Pathname+, but filters the set of files that can be accessed and does not
  # support +Pathname+'s class methods.
  #
  # If a +Pathname+ method which mutates the file system is called, it will throw an exception unless the instance is
  # mutable.
  #
  # If the underlying filesystem is modified once an instance of this path has been created, the view provided
  # by the instance will not change unless a file or directory allowed by the instance's filter is created, modified, or
  # deleted.
  class FilteringPathname

    # Create a +FilteringPathname+ which behaves like the given pathname, but which applies the given filter to all files.
    #
    # The filesystem underpinning the given pathname must not contain a file or directory whose name is the name of the
    # given pathname with '.nil' appended to it. This must be true for the lifetime of the +FilteringPathname+.
    #
    # The filter is applied to files which are accessed via the given pathname.
    # If the filter returns +true+ for a particular pathname, the pathname behaves normally for this instance.
    # If the filter returns +false+ for a particular pathname, the pathname behaves as if it does not exist.
    #
    # The +FilteringPathname+ may be immutable in which case calling a mutator method causes an exception to be thrown.
    # Alternatively, the +FilteringPathname+ may be mutable in which case calling a mutator method may mutate the
    # file system. The results of mutating the file system will be subject to filtering by the given filter.
    #
    # @param [Pathname] pathname the +Pathname+ which is to be filtered
    # @param [Proc] filter a lambda which takes a +Pathname+ and returns either +true+ (to 'keep' the pathname) or
    #         +false+ (to filter out the pathname)
    # @param [Boolean] mutable +true+ if and only if the +FilteringPathname+ may be used to mutate the file system
    def initialize(pathname, filter, mutable = false)
      @pathname     = pathname
      @filter       = filter
      @non_existent = Pathname.new "#{pathname}.nil"
      FilteringPathname.check_file_does_not_exist @non_existent
      @delegated_pathname = @filter.call(@pathname) ? @pathname : @non_existent
      @mutable            = mutable
    end

    # Dispatch superclass methods via method_missing.
    undef_method :<=>
    undef_method :==
    undef_method :===
    undef_method :taint
    undef_method :untaint

    # @see Pathname.
    def each_entry(&block)
      delegate_and_yield_visible(:each_entry, &block)
    end

    # @see Pathname.
    def entries
      visible delegate.entries
    end

    # @see Pathname.
    def open(mode = nil, perm = nil, opt = nil, &block)
      check_mutable if mode =~ /[wa]/
      delegate.open(mode, perm, opt, &block)
    end

    # @see Pathname.
    def to_s
      @filter.call(@pathname) ? delegate.to_s : ''
    end

    # @see Pathname.
    def children(with_directory = true)
      if with_directory
        super # delegate to method_missing
      else
        visible delegate.children(false)
      end
    end

    # @see Pathname.
    def each_child(with_directory = true, &block)
      if with_directory
        super # delegate to method_missing
      else
        delegate_and_yield_visible(:each_child, false, &block)
      end
    end

    private

    MUTATORS = [:chmod, :chown, :delete, :lchmod, :lchown, :make_link, :make_symlink, :mkdir, :mkpath, :rename, :rmdir, :rmtree, :taint, :unlink, :untaint].to_set.freeze

    def self.check_file_does_not_exist(file)
      fail "#{file} should not exist" if file.exist?
    end

    def check_mutable
      fail 'FilteringPathname is immutable' unless @mutable
    end

    def convert_if_necessary(r)
      if r.instance_of?(Pathname)
        @filter.call(r) ? filtered_pathname(r) : nil
      else
        r
      end
    end

    def convert_result_if_necessary(result)
      if result.instance_of? Array
        result.map { |r| convert_if_necessary(r) }.compact
      else
        result ? convert_if_necessary(result) || @non_existent : nil
      end
    end

    def delegate
      FilteringPathname.check_file_does_not_exist @non_existent
      @delegated_pathname
    end

    def delegate_and_yield_visible(method, *args)
      delegate.send(method, *args) do |y|
        yield y if visible y
      end
    end

    def filtered_pathname(pathname)
      FilteringPathname.new(pathname, @filter)
    end

    def method_missing(method, *args)
      check_mutable if MUTATORS.member? method
      if block_given?
        result = delegate.send(method, *args) do |*values|
          converted_values = values.map { |value| convert_if_necessary(value) }.compact
          yield *converted_values unless converted_values.empty? # rubocop:disable Syntax
        end
      else
        result = delegate.send(method, *args)
      end
      convert_result_if_necessary(result)
    end

    def respond_to_missing?(symbol, include_private = false)
      delegate.respond_to?(symbol, include_private)
    end

    def visible(entry)
      if entry.instance_of? Array
        entry.select { |child| visible(child) }
      else
        @filter.call(@pathname + entry)
      end
    end

  end
end
