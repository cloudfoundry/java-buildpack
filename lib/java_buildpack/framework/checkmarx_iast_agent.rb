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

require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for running with Checkmarx IAST Agent
    class CheckmarxIastAgent < JavaBuildpack::Component::BaseComponent
      include JavaBuildpack::Util

      # Creates an instance.  In addition to the functionality inherited from +BaseComponent+, +@version+ and +@uri+
      # instance variables are exposed.
      #
      # @param [Hash] context a collection of utilities used by components
      def initialize(context)
        super(context)

        # Save the IAST server URL in server, if found
        service = @application.services.find_service(FILTER, 'server')
        @server = service['credentials']['server'].chomp '/' if service
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        @server
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        # Download and extract the agent from the IAST server
        FileUtils.mkdir_p @droplet.sandbox
        # curl --insecure: most IAST servers will use self-signed SSL
        shell 'curl --fail --insecure --silent --show-error ' \
              "#{@server}/iast/compilation/download/JAVA -o #{@droplet.sandbox}/cx-agent.zip"
        shell "unzip #{@droplet.sandbox}/cx-agent.zip -d #{@droplet.sandbox}"

        # Disable cache (no point, when running in a container)
        File.open("#{@droplet.sandbox}/#{OVERRIDE_CONFIG}", 'a') do |file|
          file.write("\nenableWeavedClassCache=false\n")
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        # Default cxAppTag to application name if not set as an env var
        app_tag = ENV['cxAppTag'] || application_name
        # Default team to CxServer if not set as env var
        team = ENV['cxTeam'] || 'CxServer'

        javaagent = "-javaagent:#{qualify_path(@droplet.sandbox + JAVA_AGENT_JAR, @droplet.root)}"
        @droplet.java_opts
                .add_preformatted_options(javaagent)
                .add_preformatted_options('-Xverify:none')
                .add_system_property('cx.logToConsole', 'true')
                .add_system_property('cx.appName', application_name)
                .add_system_property('cxAppTag', app_tag)
                .add_system_property('cxTeam', team)
      end

      private

      JAVA_AGENT_JAR = 'cx-launcher.jar'

      OVERRIDE_CONFIG = 'cx_agent.override.properties'

      FILTER = /^checkmarx-iast$/.freeze

      private_constant :JAVA_AGENT_JAR, :FILTER, :OVERRIDE_CONFIG

      def application_name
        @application.details['application_name'] || 'ROOT'
      end

    end

  end

end
