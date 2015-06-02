# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
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
require 'java_buildpack/util/dash_case'
require 'java_buildpack/util/shell'
require 'tmpdir'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling PhantomJS for highcharts-export-web app.
    class PhantomJS < JavaBuildpack::Component::VersionedDependencyComponent
#      include JavaBuildpack::Util::Shell

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used by the component
      def initialize(context, &version_validator)
        super(context, &version_validator)
        @component_name = 'Phantom JS'
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar(@version, "https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.8-linux-x86_64.tar.bz2") 
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        # execute build steps for PhantomJS binary
        shell "sudo apt-get update"
        shell "sudo apt-get install build-essential chrpath libssl-dev libxft-dev -y"
        shell "sudo apt-get install libfreetype6 libfreetype6-dev -y"
        shell "sudo apt-get install libfontconfig1 libfontconfig1-dev -y"
        shell "cd /tmp"
        shell "wget https://bitbucket.org/ariya/phantomjs/downloads/$PHANTOM_JS.tar.bz2"
        shell "sudo tar xjf $PHANTOM_JS.tar.bz2"
        shell "sudo mv $PHANTOM_JS /usr/local/share"
        shell "sudo ln -sf /usr/local/share/$PHANTOM_JS/bin/phantomjs /usr/local/bin"
      end

      protected
      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        phantomjs_configured?(@application.root + 'WEB-INF/spring')
      end

      private

      def phantomjs_configured?(root_path)
        (root_path + 'export-servlet.xml').exist?
      end

    end
  end
end
