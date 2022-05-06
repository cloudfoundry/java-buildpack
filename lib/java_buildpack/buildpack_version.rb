# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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

require 'java_buildpack'
require 'java_buildpack/util/colorize'
require 'java_buildpack/util/configuration_utils'
require 'java_buildpack/util/to_b'

module JavaBuildpack

  # A representation of the buildpack's version.  The buildpack's version is determined using the following algorithm:
  #
  # 1. using the +config/version.yml+ file if it exists
  # 2. using +git+ to determine the remote and hash if the buildpack is in a git repository
  # 3. unknown
  class BuildpackVersion

    # @!attribute [r] hash
    # @return [String, nil] the Git hash of this version, or +nil+ if it cannot be determined
    attr_reader :hash

    # @!attribute [r] offline
    # @return [Boolean] +true+ if the buildpack is offline, +false+ otherwise
    attr_reader :offline

    # @!attribute [r] remote
    # @return [String, nil] the Git remote of this version, or +nil+ if it cannot be determined
    attr_reader :remote

    # @!attribute [r] version
    # @return [String, nil] the version name of this version, or +nil+ if it cannot be determined
    attr_reader :version

    # Creates a new instance
    def initialize(should_log = true)
      configuration = JavaBuildpack::Util::ConfigurationUtils.load('version', true, should_log)
      @hash         = configuration['hash'] || calculate_hash
      @offline      = configuration['offline'] || ENV.fetch('OFFLINE', nil).to_b
      @remote       = configuration['remote'] || calculate_remote
      @version      = configuration['version'] || ENV.fetch('VERSION', nil) || @hash

      return unless should_log

      logger = Logging::LoggerFactory.instance.get_logger BuildpackVersion
      logger.debug { to_s }
    end

    # Returns a +Hash+ representation of the buildpack version.
    #
    # @return [Hash] a representation of the buildpack version
    def to_hash
      h            = {}
      h['hash']    = @hash if @hash
      h['offline'] = @offline if @offline
      h['remote']  = @remote if @remote
      h['version'] = @version if @version

      h
    end

    # Creates a string representation of the version.  The string representation looks like the following:
    # +[[<VERSION> [(offline)] | ] <REMOTE>#<HASH>] | [unknown]+.  Some examples:
    #
    # +2.1.2 (offline) | https://github.com/cloudfoundry/java-buildpack.git#12345+ (custom version number, offline
    # buildpack)
    # +abcde | https://github.com/cloudfoundry/java-buildpack.git#abcde+ (default version number, online buildpack)
    # +https://github.com/cloudfoundry/java-buildpack#12345+ (cloned buildpack)
    # +unknown+ (un-packaged, un-cloned)
    #
    # @param [Boolean] human_readable whether the output should be human readable or machine readable
    # @return [String] a +String+ representation of the version
    def to_s(human_readable = true)
      s = []
      s << (human_readable ? @version.blue : @version) if @version
      s << (human_readable ? '(offline)'.blue : 'offline') if @offline

      if remote_string
        s << '|' if @version && human_readable
        s << remote_string
      end

      s << 'unknown'.yellow if s.empty?
      s.join(human_readable ? ' ' : '-')
    end

    private

    GIT_DIR = Pathname.new(__FILE__).dirname.join('..', '..', '.git').freeze

    private_constant :GIT_DIR

    def calculate_hash
      git 'rev-parse --short HEAD'
    end

    def calculate_remote
      git 'config --get remote.origin.url'
    end

    def git(command)
      `git --git-dir=#{GIT_DIR} #{command}`.chomp if git? && git_dir?
    end

    def git?
      if Gem.win_platform?
        system 'where.exe /q git.exe'
      else
        system 'which git > /dev/null'
      end
    end

    def git_dir?
      GIT_DIR.exist?
    end

    def remote_string
      "#{@remote}##{@hash}" if @remote && !@remote.empty? && @hash && !@hash.empty?
    end

  end

end
