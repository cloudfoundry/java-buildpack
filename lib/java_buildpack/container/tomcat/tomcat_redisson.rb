# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2022 the original author or authors.
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
    class TomcatRedisson < JavaBuildpack::Component::VersionedDependencyComponent
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

        download_tar(tar_name, tomcat_lib)
        Dir.glob "#{tomcat_lib}/redisson-tomcat-*-#{@version}.jar" do |jar|
          File.delete jar unless jar == "#{tomcat_lib}/redisson-tomcat-#{@tomcat_version}-#{@version}.jar"
        end

        mutate_context
        write_redisson_yaml
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release; end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, [KEY_HOST_NAME, KEY_HOST], KEY_PORT, KEY_PASSWORD
      end

      private

      FILTER = /session-replication/.freeze

      KEY_HOST_NAME = 'hostname'

      KEY_HOST = 'host'

      KEY_PASSWORD = 'password'

      KEY_PORT = 'port'

      REDIS_MANAGER_CLASS_NAME = 'org.redisson.tomcat.RedissonSessionManager'

      REDISSON_CONF_FILE = 'redisson.yaml'

      private_constant :FILTER, :KEY_HOST_NAME, :KEY_HOST, :KEY_PASSWORD, :KEY_PORT,
                       :REDISSON_CONF_FILE, :REDIS_MANAGER_CLASS_NAME

      def add_manager(context)
        # https://github.com/redisson/redisson/tree/master/redisson-tomcat
        context.add_element 'Manager',
                            'className' => REDIS_MANAGER_CLASS_NAME,
                            'configPath' => "${catalina.base}/conf/#{REDISSON_CONF_FILE}",
                            'updateMode' => @configuration['session_update_mode'],
                            'keyPrefix' => session_key_prefix
      end

      def write_redisson_yaml
        File.write(
          File.join(conf_dir, REDISSON_CONF_FILE),
          single_redis_instance.to_yaml
        )
      end

      def single_redis_instance
        credentials = @application.services.find_service(FILTER, [KEY_HOST_NAME, KEY_HOST], KEY_PORT,
                                                         KEY_PASSWORD)['credentials']

        {
          'singleServerConfig' => {
            'address' => "redis://#{credentials[KEY_HOST_NAME] || credentials[KEY_HOST]}:#{credentials[KEY_PORT]}",
            'password' => credentials[KEY_PASSWORD],
            'database' => @configuration['database'],
            'connectTimeout' => @configuration['connect_timeout'],
            'timeout' => @configuration['timeout'],
            'connectionPoolSize' => @configuration['connection_pool_size']
          }
        }
      end

      def formatter
        formatter = REXML::Formatters::Pretty.new(4)
        formatter.compact = true
        formatter
      end

      def tar_name
        "redisson-#{@version}.tgz"
      end

      def session_key_prefix
        "sessions:#{@configuration['session_key_prefix']}" if @configuration['session_key_prefix']

        "sessions:#{@configuration['default_application_name'] || @application.details['application_name']}"
      end

      def conf_dir
        @droplet.sandbox + 'conf'
      end

      def mutate_context
        puts '       Adding Redis-based Session Replication'

        document = read_xml context_xml
        context = REXML::XPath.match(document, '/Context').first

        add_manager context

        write_xml context_xml, document
      end

    end

  end
end
