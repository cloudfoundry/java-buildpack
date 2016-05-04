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

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    class Tesseract < JavaBuildpack::Component::BaseComponent

      def detect
        true
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        with_timing "Expanding tesseract ocr" do
          @droplet.copy_resources
          shell "mkdir #{@droplet.sandbox}/vendor"
          shell "tar xzf #{@droplet.sandbox}/tesseract-archive.tar.gz -C #{@droplet.sandbox}/vendor --strip-components=1 2>&1"
          shell "rm #{@droplet.sandbox}/tesseract-archive.tar.gz"
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.environment_variables.add_environment_variable 'PATH', "/home/vcap/app/.java-buildpack/tesseract/vendor/:$PATH"
        @droplet.environment_variables.add_environment_variable 'LD_LIBRARY_PATH', "/home/vcap/app/.java-buildpack/tesseract/vendor/libs:$LD_LIBRARY_PATH"
        @droplet.environment_variables.add_environment_variable 'TESSEARCT_DATA_PATH', "/home/vcap/app/.java-buildpack/tesseract/vendor/tesseract-ocr"
        
      end

      protected

      def supports?
        true
      end
    end

  end
end
