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
require 'java_buildpack/container'
require 'java_buildpack/container/tomcat/tomcat_utils'
require 'java_buildpack/container/tomcat/gemfire/gemfire'
require 'java_buildpack/container/tomcat/gemfire/gemfire_log4j_api'
require 'java_buildpack/container/tomcat/gemfire/gemfire_log4j_core'
require 'java_buildpack/container/tomcat/gemfire/gemfire_log4j_jcl'
require 'java_buildpack/container/tomcat/gemfire/gemfire_log4j_jul'
require 'java_buildpack/container/tomcat/gemfire/gemfire_log4j_slf4j_impl'
require 'java_buildpack/container/tomcat/gemfire/gemfire_logging_api'
require 'java_buildpack/container/tomcat/gemfire/gemfire_logging'
require 'java_buildpack/container/tomcat/gemfire/gemfire_modules'
require 'java_buildpack/container/tomcat/gemfire/gemfire_modules_tomcat7'
require 'java_buildpack/container/tomcat/gemfire/gemfire_security'
require 'java_buildpack/container/tomcat/tomcat_utils'
require 'java_buildpack/logging/logger_factory'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for Tomcat gemfire support.
    class TomcatGemfireStore < JavaBuildpack::Component::ModularComponent
      include JavaBuildpack::Container

      # (see JavaBuildpack::Component::ModularComponent#command)
      def compile
        super
        return unless supports?
        mutate_context
        mutate_server
        create_client_cache_config
      end

      protected

      # (see JavaBuildpack::Component::ModularComponent#sub_components)
      def sub_components(context)
        [
          GemFire.new(sub_configuration_context(context, 'gemfire')),
          GemFireLog4jApi.new(sub_configuration_context(context, 'gemfire_log4j_api')),
          GemFireLog4jCore.new(sub_configuration_context(context, 'gemfire_log4j_core')),
          GemFireLog4jJcl.new(sub_configuration_context(context, 'gemfire_log4j_jcl')),
          GemFireLog4jJul.new(sub_configuration_context(context, 'gemfire_log4j_jul')),
          GemFireLog4jSlf4jImpl.new(sub_configuration_context(context, 'gemfire_log4j_slf4j_impl')),
          GemFireLoggingApi.new(sub_configuration_context(context, 'gemfire_logging_api')),
          GemFireLogging.new(sub_configuration_context(context, 'gemfire_logging')),
          GemFireModules.new(sub_configuration_context(context, 'gemfire_modules')),
          GemFireModulesTomcat7.new(sub_configuration_context(context, 'gemfire_modules_tomcat7')),
          GemFireSecurity.new(sub_configuration_context(context, 'gemfire_security'))
        ]
      end

      # (see JavaBuildpack::Component::ModularComponent#command)
      def command
        return unless supports?
        credentials = @application.services.find_service(FILTER)['credentials']
        @droplet.java_opts.add_system_property 'gemfire.security-username', credentials[KEY_USERNAME]
        @droplet.java_opts.add_system_property 'gemfire.security-password', credentials[KEY_PASSWORD]
        @droplet.java_opts.add_system_property 'gemfire.security-client-auth-init',
                                               'templates.security.UserPasswordAuthInit.create'
      end

      # (see JavaBuildpack::Component::ModularComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, KEY_LOCATORS, KEY_USERNAME, KEY_PASSWORD
      end

      private

      FILTER = /session_replication/

      FLUSH_VALVE_CLASS_NAME = 'com.gopivotal.manager.SessionFlushValve'.freeze

      GEMFIRE_LISTENER_CLASS = 'com.gemstone.gemfire.modules.session.catalina.ClientServerCacheLifecycleListener'.freeze

      KEY_LOCATORS = 'locators'.freeze

      KEY_PASSWORD = 'password'.freeze

      KEY_USERNAME = 'username'.freeze

      PERSISTENT_MANAGER_CLASS = 'com.gemstone.gemfire.modules.session.catalina.Tomcat7DeltaSessionManager'.freeze

      private_constant :FILTER, :FLUSH_VALVE_CLASS_NAME, :KEY_LOCATORS, :KEY_PASSWORD, :KEY_USERNAME,
                       :PERSISTENT_MANAGER_CLASS, :GEMFIRE_LISTENER_CLASS

      def mutate_context
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

      def create_client_cache_config
        document = REXML::Document.new
        document << REXML::XMLDecl.new('1.0', 'UTF-8')
        document << REXML::DocType.new('client-cache PUBLIC',
                                       '"-//GemStone Systems, Inc.//GemFire Declarative Caching 7.0//EN" ' \
                                         '"http://www.gemstone.com/dtd/cache7_0.dtd"')
        add_client_pool document

        write_xml client_cache_xml_path, document
      end

      def add_manager(context)
        context.add_element 'Manager',
                            'className'                => PERSISTENT_MANAGER_CLASS,
                            'enableDebugListener'      => 'false',
                            'enableGatewayReplication' => 'false',
                            'enableLocalCache'         => 'true',
                            'enableCommitValve'        => 'true',
                            'preferDeserializedForm'   => 'true',
                            'regionAttributesId'       => 'PARTITION_REDUNDANT_PERSISTENT_OVERFLOW',
                            'regionName'               => 'sessions'
      end

      def add_listener(server)
        server.add_element 'Listener',
                           'className'                  => GEMFIRE_LISTENER_CLASS,
                           'cache-xml-file'             => client_cache_xml_name,
                           'criticalHeapPercentage'     => '0.0',
                           'evictionHeapPercentage'     => '80.0',
                           'log-file'                   => gemfire_log_file,
                           'statistic-archive-file'     => gemfire_statistics_file,
                           'statistic-sampling-enabled' => 'false'
      end

      def add_client_pool(document)
        client = document.add_element 'client-cache'

        pool = client.add_element 'pool',
                                  'name'                 => 'sessions',
                                  'subscription-enabled' => 'true'
        apply_locators_to_cache_client pool
      end

      def apply_locators_to_cache_client(pool)
        credentials = @application.services.find_service(FILTER)['credentials']

        credentials[KEY_LOCATORS].each do |locator|
          captures = locator.match(/([\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3})\[([\d]{1,6})\]/)
          pool.add_element 'locator',
                           'host' => captures[1],
                           'port' => captures[2]
        end
      end

      def client_cache_xml_path
        @droplet.sandbox + 'conf' + client_cache_xml_name
      end

      def client_cache_xml_name
        'cache-client.xml'
      end

      def gemfire_log_file
        'gemfire_modules.log'
      end

      def gemfire_statistics_file
        'gemfire_modules.gfs'
      end

    end

  end
end
