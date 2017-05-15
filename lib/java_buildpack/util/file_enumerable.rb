# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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

module JavaBuildpack
  module Util

    # Passes the open file descriptor for each candidate file to the given block.  If opening or reading the file causes
    # an error, iteration will continue, and the failing element will be assumed to have returned +true+ (i.e. failure
    # will not affect the net result of the successful elements).
    #
    # @param [Array<Pathname>] candidates the candidate files to iterate
    # @return [Boolean] +true+ if the block never returns +false+ or +nil+, otherwise +false+.
    def all?(candidates, &block)
      candidates.all? { |candidate| open(true, candidate, &block) }
    end

    # Passes the open file descriptor for each candidate file to the given block.  If opening or reading the file causes
    # an error, iteration will continue, and the failing element will be assumed to have returned +false+ (i.e. failure
    # will not affect the net result of the successful elements).
    #
    # @param [Array<Pathname>] candidates the candidate files to iterate
    # @return [Boolean] +true+ if the block always returns +false+ or +nil+, otherwise +false+.
    def none?(candidates, &block)
      candidates.none? { |candidate| open(false, candidate, &block) }
    end

    # Passes the open file descriptor for each candidate file to the given block.  If opening or reading the file causes
    # an error, iteration will continue, and the failing element will be assumed to have returned +true+ (i.e. failure
    # will not affect the net result of the successful elements).
    #
    # @param [Array<Pathname>] candidates the candidate files to iterate
    # @return [Array<Pathname>] the candidates for which the block returned +false+ or +nil+
    def reject(candidates, &block)
      candidates.reject { |candidate| open(true, candidate, &block) }
    end

    # Passes the open file descriptor for each candidate file to the given block.  If opening or reading the file causes
    # an error, iteration will continue, and the failing element will be assumed to have returned +false+ (i.e. failure
    # will not affect the net result of the successful elements).
    #
    # @param [Array<Pathname>] candidates the candidate files to iterate
    # @return [Array<Pathname>] the candidates for which the block returned +true+
    def select(candidates, &block)
      candidates.select { |candidate| open(false, candidate, &block) }
    end

    private

    def open(default, candidate, &block)
      candidate.open('r', external_encoding: 'UTF-8', &block)
    rescue => e
      @logger.warn e.message
      default
    end

  end
end
