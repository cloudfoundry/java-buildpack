# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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
require 'java_buildpack/util/configuration_utils'

module JavaBuildpack

  # A representation of the buildpack's version.  The buildpack's version is determined using the following algorithm:
  #
  # 1. using the +config/version.yml+ file if it exists
  # 2. using +git+ to determine the remote and hash if the buildpack is in a git repository
  # 3. unknown
  class BuildpackVersion

    # Creates a new instance
    def initialize
      configuration = JavaBuildpack::Util::ConfigurationUtils.load 'version'
      @hash         = configuration['hash'] || hash
      @offline      = configuration['offline']
      @remote       = configuration['remote'] || remote
      @version      = configuration['version']

      logger = Logging::LoggerFactory.instance.get_logger BuildpackVersion
      logger.debug { to_s }
    end

    # Creates a string representation of the version.  The string representation looks like the following:
    # +[[<VERSION> [(offline)] | ] <REMOTE>#<HASH>] | [unknown]+.  Some examples:
    #
    # +2.1.2 (offline) | https://github.com/cloudfoundry/java-buildpack.git#12345+ (custom version number, offline buildpack)
    # +abcde | https://github.com/cloudfoundry/java-buildpack.git#abcde+ (default version number, online buildpack)
    # +https://github.com/cloudfoundry/java-buildpack#12345+ (cloned buildpack)
    # +unknown+ (un-packaged, un-cloned)
    #
    # @param [Boolean] human_readable whether the output should be human readable or machine readable
    # @return [String] a +String+ representation of the version
    def to_s(human_readable = true)
      s = []
      s << @version if @version
      s << (human_readable ? '(offline)' : 'offline') if @offline
      s << '|' if @version && human_readable
      s << "#{@remote}##{@hash}" if @remote && @hash
      s << 'unknown' if s.empty?

      s.join(human_readable ? ' ' : '-')
    end

    private

    GIT_DIR = (Pathname.new(__FILE__).dirname + '../../.git').freeze

    private_constant :GIT_DIR

    def git(command)
      `git --git-dir=#{GIT_DIR} #{command}`.chomp if git? && git_dir?
    end

    def git?
      system 'which git > /dev/null'
    end

    def git_dir?
      GIT_DIR.exist?
    end

    def hash
      git 'rev-parse --short HEAD'
    end

    def remote
      git 'config --get remote.origin.url'
    end

  end

end
