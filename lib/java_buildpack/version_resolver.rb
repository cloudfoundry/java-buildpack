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

module JavaBuildpack

  # A resolver that selects values from a collection based on a set of rules governing wildcards
  class VersionResolver

    # Resolves a version from a collection of versions.  The +candidate_version+ must be structured like:
    #   * up to three numeric components, followed by an optional string component
    #   * the final component may be a +
    # The resolution returns the maximum of the versions that match the candidate version
    #
    # @param [String, nil] candidate_version the version, possibly containing a wildcard, to resolve
    # @param [String, nil] default_version the version, possibly containing a wildcard, to resolve if
    #                                      +candidate_version+ is +nil+
    # @param [Array<String>] versions the collection of versions to resolve against
    # @return [String] the resolved version
    # @raise if no version can be resolved
    def self.resolve(candidate_version, default_version, versions)
      tokenized_candidate_version = TokenizedVersion.new(
        candidate_version.nil? || candidate_version.empty? ? default_version : candidate_version)
      tokenized_versions = versions.map { |version| TokenizedVersion.new(version, false) }

      version = tokenized_versions
        .find_all { |tokenized_version| matches tokenized_candidate_version, tokenized_version }
        .max { |a, b| a <=> b }

      raise "No version resolvable for '#{candidate_version}' in #{versions.join(', ')}" if version.nil?
      version.to_s
    end

    private

    def self.matches(tokenized_candidate_version, tokenized_version)
      (0..3).all? do |i|
        tokenized_candidate_version[i].nil? ||
        tokenized_candidate_version[i] == TokenizedVersion::WILDCARD ||
        tokenized_candidate_version[i] == tokenized_version[i]
      end
    end

    # @private
    class TokenizedVersion < Array
      include Comparable

      # @private
      WILDCARD = '+'

      def initialize(version, allow_wildcards = true)
        @version = version

        major, tail = major_or_minor_and_tail version
        minor, tail = major_or_minor_and_tail tail
        micro, qualifier = micro_and_qualifier tail

        self.concat [major, minor, micro, qualifier]
        validate allow_wildcards
      end

      # @private
      def <=>(another)
        comparison = self[0] <=> another[0]
        comparison = self[1] <=> another[1] if comparison == 0
        comparison = self[2] <=> another[2] if comparison == 0
        comparison = qualifier_compare(self[3].nil? ? '' : self[3], another[3].nil? ? '' : another[3]) if comparison == 0

        comparison
      end

      # @private
      def to_s
        @version
      end

      private

      COLLATING_SEQUENCE = ['-'] + ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a

      def char_compare(c1, c2)
        COLLATING_SEQUENCE.index(c1) <=> COLLATING_SEQUENCE.index(c2)
      end

      def major_or_minor_and_tail(s)
        if s.nil? || s.empty?
          major_or_minor, tail = nil, nil
        else
          raise "Invalid version '#{s}': must not end in '.'" if s[-1] == '.'
          tokens = s.match(/^([^\.]+)(?:\.(.*))?/)

          major_or_minor, tail = tokens[1..-1]

          raise "Invalid major or minor version '#{major_or_minor}'" unless valid_major_minor_or_micro major_or_minor
        end

        return major_or_minor, tail
      end

      def micro_and_qualifier(s)
        if s.nil? || s.empty?
          micro, qualifier = nil, nil
        else
          raise "Invalid version '#{s}': must not end in '_'" if s[-1] == '_'
          tokens = s.match(/^([^\_]+)(?:_(.*))?/)

          micro, qualifier = tokens[1..-1]

          raise "Invalid micro version '#{micro}'" unless valid_major_minor_or_micro micro
          raise "Invalid qualifier '#{qualifier}'" unless valid_qualifier qualifier
        end

        return micro, qualifier
      end

      def minimum_qualifier_length(a, b)
        [a.length, b.length].min
      end

      def qualifier_compare(a, b)
        comparison = 0

        i = 0
        until comparison != 0 || i == minimum_qualifier_length(a, b)
          comparison = char_compare(a[i], b[i])
          i += 1
        end

        comparison = a.length <=> b.length  if comparison == 0

        comparison
      end

      def validate(allow_wildcards)
        post_wildcard = false
        self.each do |value|
          raise "Wildcards are not allow in version '#{@version}'" if value == WILDCARD && !allow_wildcards

          raise "No values are allowed after wildcard in version '#{@version}'" if post_wildcard && !value.nil?
          post_wildcard = true if value == WILDCARD
        end
      end

      def valid_major_minor_or_micro(major_minor_or_micro)
        major_minor_or_micro =~ /^[\d]*$/ || major_minor_or_micro =~ /^\+$/
      end

      def valid_qualifier(qualifier)
        qualifier.nil? || qualifier.empty? || qualifier =~ /^[-a-zA-Z\d]*$/ || qualifier =~ /^\+$/
      end
    end

  end
end
