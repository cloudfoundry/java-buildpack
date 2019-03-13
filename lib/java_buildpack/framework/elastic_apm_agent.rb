# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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

    # Encapsulates the functionality for enabling zero-touch Elastic APM support.
    class ElasticApmAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        puts "compile - ElasticApmAgent download_uri=#{@uri} version=#{@version}"
        download_jar
        print "compile - ElasticApmAgent  droplet.copy_resources @component_name= #{@component_name}"
        @droplet.copy_resources
        Dir.foreach("./app") {|x| puts "ElasticApmAgent Got #{x}" }
        puts "compile - ElasticApmAgent  end  "
      end

      # Modifies the application's runtime configuration. The component is expected to transform members of the
      # +context+ # (e.g. +@java_home+, +@java_opts+, etc.) in whatever way is necessary to support the function of the
      # component.
      #
      # Container components are also expected to create the command required to run the application.  These components
      # are expected to read the +context+ values and take them into account when creating the command.
      #
      # @return [void, String] components other than containers and JREs are not expected to return any value.
      #                        Container and JRE components are expected to return a command required to run the
      #                        application.
      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials   = @application.services.find_service(FILTER, [SERVER_URL, APPLICATION_PACKAGES])['credentials']
        java_opts     = @droplet.java_opts
        configuration = {}

        apply_configuration(credentials, configuration)
        apply_user_configuration(credentials, configuration)

        unless jar_name.empty? then jar_name else 'elastic-apm-agent-1.4.0.jar' end

        java_opts.add_javaagent(@droplet.sandbox + jar_name)
                  .add_system_property('elkapmagent.home', @droplet.sandbox)
        java_opts.add_system_property('elastic.apm.application_packages.enable.java.8', 'true') if @droplet.java_home.java_8_or_later?
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        support_val=false
        support_val=@application.services.one_service? FILTER, [SERVER_URL, APPLICATION_PACKAGES]
        support_val
      end

      private

      FILTER = /elasticapm/

      BASE_KEY = 'elastic.apm.'

      SERVER_URL = 'server_urls'

      APPLICATION_PACKAGES = 'application_packages'

      private_constant :FILTER, :SERVER_URL, :APPLICATION_PACKAGES, :BASE_KEY

      def apply_configuration(credentials, configuration)
        configuration['log_file_name']  = 'STDOUT'
        configuration[SERVER_URL] = credentials[SERVER_URL]
        configuration[APPLICATION_PACKAGES] = credentials[APPLICATION_PACKAGES]
        configuration['elastic.apm.service_name'] = @application.details['application_name']
      end

      def apply_user_configuration(credentials, configuration)
        credentials.each do |key, value|
          configuration[key] = value
        end
      end

      def write_java_opts(java_opts, configuration)
        print "ElasticApmAgent - write_java_opts "
        configuration.each do |key, value|
          java_opts.add_system_property("elastic.apm.#{key}", value)
        end
      end

      # download(@version, @uri) { |file| expand file }
      # configuration
      # version: 1.4.0
      # repository_root: https://repo1.maven.org/maven2/co/elastic/apm/elastic-apm-agent/
      # repository_download: https://repo1.maven.org/maven2/co/elastic/apm/elastic-apm-agent/1.4.0/elastic-apm-agent-1.4.0.jar
      def elastic_agent_download_url
        puts "ElasticApmAgent - elastic_agent_download_url "
        config_version="#{@configuration['version']}"
        config_root="#{@configuration['repository_root']}"
        config_default="#{@configuration['repository_download']}"
        puts "- ElasticApmAgent elastic_agent_download_url #{config_root} ver=#{config_version} "
        # repository_download: https://repo1.maven.org/maven2/co/elastic/apm/elastic-apm-agent/1.4.0/elastic-apm-agent-1.4.0.jar
        download_uri = "#{config_root}#{config_version}/elastic-apm-agent-#{config_version}.jar"
        # @TODO if download_uri!valid then download_uri=config_default

        [config_version, download_uri]
      end

      # Downloads an item with the given name and version from the given URI, then yields the resultant file to the
      # given # block.
      #
      # @param [JavaBuildpack::Util::TokenizedVersion] version
      # @param [String] uri
      # @param [String] name an optional name for the download.  Defaults to +@component_name+.
      # @return [Void]
      def download_elastic(version, uri, name = @component_name)
        download_start_time = Time.now
        print "#{'----->'.red.bold} ElasticApmAgent Downloading #{name.blue.bold} #{version.to_s.blue} from #{uri.sanitize_uri} "

        JavaBuildpack::Util::Cache::CacheFactory.create.get(uri) do |file, downloaded|
          if downloaded
            puts "(#{(Time.now - download_start_time).duration})".green.italic
          else
            puts '(found in cache)'.green.italic
          end

          yield file
        end
      end

    end
  end
end
