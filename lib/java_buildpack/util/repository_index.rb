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
require 'java_buildpack/util/download_cache'

module JavaBuildpack::Util

  # A class representing the contents of a repository's index
  class RepositoryIndex < Hash

    # Create a new instance, populating it with values from a repository's index
    #
    # @param [String] key the repository
    # @param [String] repository_root the root of the repository to create the index for
    def initialize(key, repository_root)
      DownloadCache.new().get(key, "#{repository_root}#{INDEX_PATH}") do |file| # TODO Use global cache #50175265
        self.merge! YAML.load_file(file)
      end
    end

    private

    INDEX_PATH = '/index.yml'

  end

end
