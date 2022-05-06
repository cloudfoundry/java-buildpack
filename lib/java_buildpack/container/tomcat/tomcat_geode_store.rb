# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2021 the original author or authors.
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
require 'java_buildpack/container'
require 'java_buildpack/container/tomcat/tomcat_utils'
require 'java_buildpack/logging/logger_factory'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for Tomcat Tanzu GemFire for VMs support.
    class TomcatGeodeStore < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Container

      # Creates an instance.  In addition to the functionality inherited from +VersionedDependencyComponent+
      # +@tomcat_version+ instance variable is exposed.
      #
      # @param [Hash] context a collection of utilities used by components
      # @param [String] tomcat_version is the major version of tomcat
      def initialize(context, tomcat_version)
        super(context)
        @tomcat_version = tomcat_version
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        return unless supports?

        download_tar(false, tomcat_lib, tar_name)
        detect_geode_tomcat_version
        mutate_context
        mutate_server
        create_cache_client_xml
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        return unless supports?

        @droplet.java_opts.add_system_property 'gemfire.security-client-auth-init',
                                               'io.pivotal.cloudcache.ClientAuthInitialize.create'
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, KEY_LOCATORS, KEY_USERS
      end

      private

      FILTER = /session-replication/.freeze
      KEY_LOCATORS = 'locators'
      KEY_USERS = 'users'

      REGION_ATTRIBUTES_ID = 'PARTITION_REDUNDANT_HEAP_LRU'
      CACHE_CLIENT_LISTENER_CLASS_NAME =
        'org.apache.geode.modules.session.catalina.ClientServerCacheLifecycleListener'
      SCHEMA_URL = 'http://geode.apache.org/schema/cache'
      SCHEMA_INSTANCE_URL = 'http://www.w3.org/2001/XMLSchema-instance'
      SCHEMA_LOCATION = 'http://geode.apache.org/schema/cache http://geode.apache.org/schema/cache/cache-1.0.xsd'
      LOCATOR_REGEXP = Regexp.new('([^\\[]+)\\[([^\\]]+)\\]').freeze

      private_constant :FILTER, :KEY_LOCATORS, :KEY_USERS, :REGION_ATTRIBUTES_ID,
                       :CACHE_CLIENT_LISTENER_CLASS_NAME, :SCHEMA_URL, :SCHEMA_INSTANCE_URL, :SCHEMA_LOCATION,
                       :LOCATOR_REGEXP

      def add_client_cache(document)
        client_cache = document.add_element 'client-cache',
                                            'xmlns' => SCHEMA_URL,
                                            'xmlns:xsi' => SCHEMA_INSTANCE_URL,
                                            'xsi:schemaLocation' => SCHEMA_LOCATION,
                                            'version' => '1.0'

        add_pool client_cache
      end

      def add_listener(server)
        server.add_element 'Listener',
                           'className' => CACHE_CLIENT_LISTENER_CLASS_NAME
      end

      def add_locators(pool)
        service = @application.services.find_service FILTER, KEY_LOCATORS, KEY_USERS
        service['credentials']['locators'].each do |locator|
          match_info = LOCATOR_REGEXP.match(locator)
          pool.add_element 'locator',
                           'host' => match_info[1],
                           'port' => match_info[2]
        end
      end

      def add_manager(context)
        context.add_element 'Manager',
                            'className' => @session_manager_classname,
                            'enableLocalCache' => 'true',
                            'regionAttributesId' => REGION_ATTRIBUTES_ID
      end

      def add_pool(client_cache)
        pool = client_cache.add_element 'pool',
                                        'name' => 'sessions',
                                        'subscription-enabled' => 'true'
        add_locators pool
      end

      def cache_client_xml
        'cache-client.xml'
      end

      def cache_client_xml_path
        @droplet.sandbox + 'conf' + cache_client_xml
      end

      def create_cache_client_xml
        document = REXML::Document.new('<?xml version="1.0" encoding="UTF-8"?>')
        add_client_cache document
        write_xml cache_client_xml_path, document
      end

      def detect_geode_tomcat_version
        geode_tomcat_version = nil

        geode_modules_tomcat_pattern = /geode-modules-tomcat(?<version>[0-9]*).*.jar/.freeze
        Dir.foreach(@droplet.sandbox + 'lib') do |file|
          if geode_modules_tomcat_pattern.match(file)
            unless geode_tomcat_version.nil?
              raise('Multiple versions of geode-modules-tomcat jar found. ' \
                    'Please verify your geode_store tar only contains one geode-modules-tomcat jar.')
            end

            geode_tomcat_version = geode_modules_tomcat_pattern.match(file).named_captures['version']
          end
        end

        if geode_tomcat_version.nil?
          raise('Geode Tomcat module not found. ' \
                'Please verify your geode_store tar contains a geode-modules-tomcat jar.')
        end

        puts "       Detected Geode Tomcat #{geode_tomcat_version} module"

        # leave possibility for generic jar/session manager class that is compatible with all tomcat versions
        if !geode_tomcat_version.empty? && geode_tomcat_version != @tomcat_version
          puts "       WARNING: Tomcat version #{@tomcat_version} " \
               "does not match Geode Tomcat #{geode_tomcat_version} module. " \
               'If you encounter compatibility issues, please make sure these versions match.'
        end

        @session_manager_classname =
          "org.apache.geode.modules.session.catalina.Tomcat#{geode_tomcat_version}DeltaSessionManager"
      end

      def mutate_context
        puts '       Adding Geode-based Session Replication'
        document = read_xml context_xml
        context = REXML::XPath.match(document, '/Context').first

        add_manager context

        write_xml context_xml, document
      end

      def mutate_server
        document = read_xml server_xml

        server = REXML::XPath.match(document, '/Server').first

        add_listener server

        write_xml server_xml, document
      end

      def tar_name
        "geode-store-#{@version}.tar.gz"
      end

    end

  end
end
