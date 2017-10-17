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
require 'java_buildpack/container'
require 'java_buildpack/container/tomcat/tomcat_utils'
require 'java_buildpack/logging/logger_factory'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for Tomcat Redis support.
    class TomcatRedisStore < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Container

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        return unless supports?

        download_jar(jar_name, tomcat_lib)
        mutate_context
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release; end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, [KEY_HOST_NAME, KEY_HOST], KEY_PORT, KEY_PASSWORD
      end

      private

      FILTER = /session-replication/

      FLUSH_VALVE_CLASS_NAME = 'com.gopivotal.manager.SessionFlushValve'.freeze

      KEY_HOST_NAME = 'hostname'.freeze

      KEY_HOST = 'host'.freeze

      KEY_PASSWORD = 'password'.freeze

      KEY_PORT = 'port'.freeze

      PERSISTENT_MANAGER_CLASS_NAME = 'org.apache.catalina.session.PersistentManager'.freeze

      REDIS_STORE_CLASS_NAME = 'com.gopivotal.manager.redis.RedisStore'.freeze

      private_constant :FILTER, :FLUSH_VALVE_CLASS_NAME, :KEY_HOST_NAME, :KEY_PASSWORD, :KEY_PORT,
                       :PERSISTENT_MANAGER_CLASS_NAME, :REDIS_STORE_CLASS_NAME

      def add_manager(context)
        manager = context.add_element 'Manager', 'className' => PERSISTENT_MANAGER_CLASS_NAME
        add_store manager
      end

      def add_store(manager)
        credentials = @application.services.find_service(FILTER, [KEY_HOST_NAME, KEY_HOST], KEY_PORT,
                                                         KEY_PASSWORD)['credentials']

        manager.add_element 'Store',
                            'className'          => REDIS_STORE_CLASS_NAME,
                            'host'               => credentials[KEY_HOST_NAME] || credentials[KEY_HOST],
                            'port'               => credentials[KEY_PORT],
                            'database'           => @configuration['database'],
                            'password'           => credentials[KEY_PASSWORD],
                            'timeout'            => @configuration['timeout'],
                            'connectionPoolSize' => @configuration['connection_pool_size']
      end

      def add_valve(context)
        context.add_element 'Valve', 'className' => FLUSH_VALVE_CLASS_NAME
      end

      def formatter
        formatter         = REXML::Formatters::Pretty.new(4)
        formatter.compact = true
        formatter
      end

      def jar_name
        "redis_store-#{@version}.jar"
      end

      def mutate_context
        puts '       Adding Redis-based Session Replication'

        document = read_xml context_xml
        context  = REXML::XPath.match(document, '/Context').first

        add_valve context
        add_manager context

        write_xml context_xml, document
      end

    end

  end
end
