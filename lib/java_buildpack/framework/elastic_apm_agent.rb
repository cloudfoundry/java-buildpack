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
    class ElasticApmAgent < JavaBuildpack::Component::BaseComponent


      # Creates an instance.  In addition to the functionality inherited from +BaseComponent+, +@version+ and +@uri+
      # instance variables are exposed.
      #
      # @param [Hash] context a collection of utilities used by components
      def initialize(context)
        super(context)
        print "-initialize ElasticApmAgent configuration= #{@configuration['repository_download']} <-static default "
        @version, @uri = elastic_agent_download_url if supports?
        @logger        = JavaBuildpack::Logging::LoggerFactory.instance.get_logger ElasticApmAgent
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        print "compile - ElasticApmAgent download uri=#{@uri} version=#{@version}"
        download(@version, @uri)
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        print "release - ElasticApmAgent < JavaBuildpack::Component::VersionedDependencyComponent "
        credentials   = @application.services.find_service(FILTER, [SERVER_URL, APPLICATION_PACKAGES])['credentials']
        java_opts     = @droplet.java_opts
        configuration = {}

        apply_configuration(credentials, configuration)
        apply_user_configuration(credentials, configuration)
        write_java_opts(java_opts, configuration)

        java_opts.add_javaagent(@droplet.sandbox + jar_name)
                 .add_system_property('elkapmagent.home', @droplet.sandbox)
        java_opts.add_system_property('elastic.apm.application_packages.enable.java.8', 'true') if @droplet.java_home.java_8_or_later?
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        @version ? id(@version) : nil
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        print "supports? - ElasticApmAgent "
        @application.services.one_service? FILTER, [SERVER_URL, APPLICATION_PACKAGES]
      end

      private

      FILTER = /elasticapm/

      BASE_KEY = 'elastic.apm.'

      SERVER_URL = 'server_urls'

      APPLICATION_PACKAGES = 'application_packages'

      private_constant :FILTER, :SERVER_URL, :APPLICATION_PACKAGES, :BASE_KEY

      def apply_configuration(credentials, configuration)
        print "apply_configuration configuration"
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

        config_version="#{@configuration['version']}"
        config_root="#{@configuration['repository_root']}"
        config_default="#{@configuration['repository_download']}"
        print "- ElasticApmAgent elastic_agent_download_url #{config_root} ver=#{config_version} "
        # repository_download: https://repo1.maven.org/maven2/co/elastic/apm/elastic-apm-agent/1.4.0/elastic-apm-agent-1.4.0.jar
        download_uri = "#{config_root}#{config_version}/elastic-apm-agent-#{config_version}.jar}"
        # @TODO if download_uri!valid then download_uri=config_default
        [config_version, download_uri]
      end

    end

  end
end
