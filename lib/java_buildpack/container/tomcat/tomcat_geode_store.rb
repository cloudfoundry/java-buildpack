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
require 'java_buildpack/container'
require 'java_buildpack/container/tomcat/tomcat_utils'
require 'java_buildpack/logging/logger_factory'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for Tomcat Redis support.
    class TomcatGeodeStore < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Container

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        return unless supports?
        download_tar(false, tomcat_lib, tar_name)
        mutate_context
        mutate_server
        create_cache_client_xml
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        return unless supports?
        credentials = @application.services.find_service(FILTER, KEY_LOCATORS, KEY_USERS)['credentials']
        user = credentials[KEY_USERS].find { |u| cluster_operator?(u) }

        @droplet.java_opts.add_system_property 'gemfire.security-username', user['username']
        @droplet.java_opts.add_system_property 'gemfire.security-password', user['password']
        @droplet.java_opts.add_system_property 'gemfire.security-client-auth-init',
                                               'io.pivotal.cloudcache.ClientAuthInitialize.create'
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, KEY_LOCATORS, KEY_USERS
      end

      private

      FILTER = /session-replication/
      KEY_LOCATORS = 'locators'
      KEY_USERS = 'users'

      SESSION_MANAGER_CLASS_NAME = 'org.apache.geode.modules.session.catalina.Tomcat8DeltaSessionManager'
      REGION_ATTRIBUTES_ID = 'PARTITION_REDUNDANT_HEAP_LRU'
      CACHE_CLIENT_LISTENER_CLASS_NAME =
        'org.apache.geode.modules.session.catalina.ClientServerCacheLifecycleListener'
      SCHEMA_URL = 'http://geode.apache.org/schema/cache'
      SCHEMA_INSTANCE_URL = 'http://www.w3.org/2001/XMLSchema-instance'
      SCHEMA_LOCATION = 'http://geode.apache.org/schema/cache http://geode.apache.org/schema/cache/cache-1.0.xsd'
      LOCATOR_REGEXP = Regexp.new('([^\\[]+)\\[([^\\]]+)\\]').freeze
      FUNCTION_SERVICE_CLASS_NAMES = [
        'org.apache.geode.modules.util.CreateRegionFunction',
        'org.apache.geode.modules.util.TouchPartitionedRegionEntriesFunction',
        'org.apache.geode.modules.util.TouchReplicatedRegionEntriesFunction',
        'org.apache.geode.modules.util.RegionSizeFunction'
      ].freeze

      private_constant :FILTER, :KEY_LOCATORS, :KEY_USERS, :SESSION_MANAGER_CLASS_NAME, :REGION_ATTRIBUTES_ID,
                       :CACHE_CLIENT_LISTENER_CLASS_NAME, :SCHEMA_URL, :SCHEMA_INSTANCE_URL, :SCHEMA_LOCATION,
                       :LOCATOR_REGEXP, :FUNCTION_SERVICE_CLASS_NAMES

      def cluster_operator?(user)
        user['username'] == 'cluster_operator' || user['roles'] && (user['roles'].include? 'cluster_operator')
      end

      def add_client_cache(document)
        client_cache = document.add_element 'client-cache',
                                            'xmlns' => SCHEMA_URL,
                                            'xmlns:xsi' => SCHEMA_INSTANCE_URL,
                                            'xsi:schemaLocation' => SCHEMA_LOCATION,
                                            'version' => '1.0'

        add_pool client_cache
        add_function_service client_cache
      end

      def add_functions(function_service)
        FUNCTION_SERVICE_CLASS_NAMES.each do |function_class_name|
          function = function_service.add_element 'function'
          class_name = function.add_element 'class-name'
          class_name.add_text(function_class_name)
        end
      end

      def add_function_service(client_cache)
        function_service = client_cache.add_element 'function-service'
        add_functions function_service
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
                            'className' => SESSION_MANAGER_CLASS_NAME,
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

      def mutate_context
        puts '       Adding Geode-based Session Replication'

        document = read_xml context_xml
        context  = REXML::XPath.match(document, '/Context').first

        add_manager context

        write_xml context_xml, document
      end

      def mutate_server
        document = read_xml server_xml

        server   = REXML::XPath.match(document, '/Server').first

        add_listener server

        write_xml server_xml, document
      end

      def tar_name
        "geode-store-#{@version}.tar.gz"
      end

    end

  end
end
