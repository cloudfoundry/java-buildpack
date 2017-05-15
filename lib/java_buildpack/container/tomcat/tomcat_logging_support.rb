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

require 'java_buildpack/component/versioned_dependency_component'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for Tomcat logging support.
    class TomcatLoggingSupport < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar(jar_name, endorsed)
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.java_opts.add_system_property 'java.endorsed.dirs',
                                               "$PWD/#{endorsed.relative_path_from(@droplet.root)}"
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        true
      end

      private

      def endorsed
        @droplet.sandbox + 'endorsed'
      end

      def jar_name
        "tomcat_logging_support-#{@version}.jar"
      end

    end

  end
end
