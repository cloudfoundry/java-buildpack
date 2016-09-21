# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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

module JavaBuildpack
  module Util

    # This class conforms to the interface of +Pathname+, but filters the set of files that can be accessed and does not
    # support +Pathname+'s class methods. This class also provides a +glob+ instance method which filters its output.
    #
    # If a +Pathname+ method which mutates the file system is called, it will throw an exception unless the instance is
    # created as mutable.
    #
    # If the underlying filesystem is modified once an instance of this path has been created, the view provided
    # by the instance will not change unless a file or directory allowed by the instance's filter is created, modified,
    # or deleted.
    class FilteringPathname

      # Create a +FilteringPathname+ which behaves like the given pathname, but which applies the given filter to all
      # files.
      #
      # The filesystem underpinning the given pathname must not contain a file or directory whose name is the name of
      # the given pathname with '.nil' appended to it. This must be true for the lifetime of the +FilteringPathname+.
      #
      # The filter is applied to files which are accessed via the given pathname.
      # If the filter returns +true+ for a particular pathname, the pathname behaves normally for this instance.
      # If the filter returns +false+ for a particular pathname, the pathname behaves as if it does not exist.
      #
      # Note that the filter must obey the following rule: if the filter accepts Pathnames p and r, where p is a parent
      # directory of r, then the filter must accept every Pathname q where p is a parent directory of q and q is a
      # parent directory of r. FilteringPathname does not check that the filter obeys this rule.
      #
      # The +FilteringPathname+ may be immutable in which case calling a mutator method causes an exception to be
      # thrown. Alternatively, the +FilteringPathname+ may be mutable in which case calling a mutator method may mutate
      # the file system. The results of mutating the file system will be subject to filtering by the given filter.
      #
      # @param [Pathname] pathname the +Pathname+ which is to be filtered
      # @param [Proc] filter a lambda which takes a +Pathname+ and returns either +true+ (to 'keep' the pathname) or
      #         +false+ (to filter out the pathname).  Defaults to keeping everything
      # @param [Boolean] mutable +true+ if and only if the +FilteringPathname+ may be used to mutate the file system
      def initialize(pathname, filter, mutable)
        raise 'Non-absolute pathname' unless pathname.absolute?

        @pathname = pathname
        @filter   = filter
        @mutable  = mutable

        @non_existent = Pathname.new "#{pathname}.nil"
        check_file_does_not_exist @non_existent

        @delegated_pathname = filter(@pathname) ? @pathname : @non_existent
      end

      # @see Pathname.
      def <=>(other)
        @pathname <=> comparison_target(other)
      end

      # @see Pathname.
      def ==(other)
        @pathname == comparison_target(other)
      end

      # @see Pathname.
      def ===(other)
        @pathname === comparison_target(other) # rubocop:disable Style/CaseEquality
      end

      # Dispatch superclass methods via method_missing.
      undef_method :taint
      undef_method :untaint

      # @see Pathname.
      def +(other)
        filtered_pathname(@pathname + other)
      end

      # @see Pathname.
      def each_entry(&block)
        delegate_and_yield_visible(:each_entry, &block)
      end

      # @see Pathname.
      def entries
        visible delegate.entries
      end

      # @see Pathname.
      def open(mode = nil, *args, &block)
        check_mutable if mode =~ /[wa]/
        delegate.open(mode, *args, &block)
      end

      # @see Pathname.
      def to_s
        @pathname.to_s
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

      # Execute this +FilteringPathname+ as a glob.
      def glob(flags = 0)
        if block_given?
          Pathname.glob(@pathname, flags) do |file|
            yield filtered_pathname(file) if visible file
          end
        else
          result = Pathname.glob(@pathname, flags)
          convert_result_if_necessary(result)
        end
      end

      attr_reader :pathname

      protected :pathname

      private

      MUTATORS = [:chmod, :chown, :delete, :lchmod, :lchown, :make_link, :make_symlink, :mkdir, :mkpath, :rename,
                  :rmdir, :rmtree, :taint, :unlink, :untaint].to_set.freeze

      private_constant :MUTATORS

      def check_file_does_not_exist(file)
        raise "#{file} should not exist" if file.exist?
      end

      def check_mutable
        raise 'FilteringPathname is immutable' unless @mutable
      end

      def comparison_target(other)
        other.instance_of?(FilteringPathname) ? other.pathname : other
      end

      def convert_if_necessary(r)
        if r.instance_of?(Pathname) && r.absolute?
          filter(r) ? filtered_pathname(r) : nil
        else
          r
        end
      end

      def convert_result_if_necessary(result)
        if result.instance_of? Array
          result.map { |r| convert_if_necessary(r) }.compact
        else
          result ? convert_if_necessary(result) || filtered_pathname(@non_existent) : nil
        end
      end

      def delegate
        check_file_does_not_exist @non_existent
        @delegated_pathname
      end

      def delegate_and_yield_visible(method, *args)
        delegate.send(method, *args) do |y|
          yield y if visible y
        end
      end

      def filtered_pathname(pathname)
        FilteringPathname.new(pathname, @filter, @mutable)
      end

      def method_missing(method, *args)
        check_mutable if MUTATORS.member? method
        if block_given?
          result = delegate.send(method, *args) do |*values|
            converted_values = values.map { |value| convert_if_necessary(value) }.compact
            yield(*converted_values) unless converted_values.empty?
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
          filter(@pathname + entry)
        end
      end

      def filter(pathname)
        raise 'Non-absolute pathname' unless pathname.absolute?
        @filter.call(pathname.cleanpath)
      end

    end

  end
end
