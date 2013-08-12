# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/download'

module JavaBuildpack::Framework

  # Encapsulates the detect, compile, and release functionality for enabling New Relic auto configuration.
  class NewRelic

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [Hash] :vcap_application The contents of the +VCAP_APPLICATION+ environment variable
    # @option context [Hash] :vcap_services The contents of the +VCAP_SERVICES+ environment variable
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context = {})
      @app_dir = context[:app_dir]
      @java_opts = context[:java_opts]
      @vcap_application = context[:vcap_application]
      @vcap_services = context[:vcap_services]
      @configuration = context[:configuration]
      @version, @uri = NewRelic.find_new_relic_agent(@vcap_services, @configuration)
    end

    # Detects whether this application is suitable for New Relic
    #
    # @return [String] returns +new-relic-<version>+ if the application is a candidate for  New Relic otherwise returns
    #                  +nil+
    def detect
      @version ? id(@version) : nil
    end

    # Downloads the Auto-reconfiguration JAR
    #
    # @return [void]
    def compile
      system "rm -rf #{new_relic_home}"
      system "mkdir -p #{new_relic_home}"
      system "mkdir -p #{File.join new_relic_home, 'logs'}"

      JavaBuildpack::Util.download(@version, @uri, 'New Relic Agent', jar_name(@version), new_relic_home)
      copy_resources new_relic_home
    end

    # Adds configuration information to +JAVA_OPTS+
    #
    # @return [void]
    def release
      @java_opts << "-javaagent:#{File.join NEW_RELIC_HOME, jar_name(@version)}"
      @java_opts << "-Dnewrelic.home=#{NEW_RELIC_HOME}"
      @java_opts << "-Dnewrelic.config.license_key=#{NewRelic.license_key @vcap_services}"
      @java_opts << "-Dnewrelic.config.app_name='#{@vcap_application[NAME_KEY]}'"
      @java_opts << "-Dnewrelic.config.log_file_path=#{File.join NEW_RELIC_HOME, 'logs'}"
    end

    private

      NAME_KEY = 'application_name'

      RESOURCES = File.join('..', '..', '..', 'resources', 'new-relic').freeze

      NEW_RELIC_HOME = '.new-relic'.freeze

      def copy_resources(new_relic_home)
        resources = File.expand_path(RESOURCES, File.dirname(__FILE__))
        system "cp -r #{File.join resources, '*'} #{new_relic_home}"
      end

      def self.find_new_relic_agent(vcap_services, configuration)
        if license_key(vcap_services)
          version, uri = JavaBuildpack::Repository::ConfiguredItem.find_item(configuration)
        else
          version = nil
          uri = nil
        end

        return version, uri # rubocop:disable RedundantReturn
      end

      def id(version)
        "new-relic-#{version}"
      end

      def jar_name(version)
        "#{id version}.jar"
      end

      def self.license_key(vcap_services)
        license_key = nil

        type = vcap_services.keys.find { |key| key =~ /newrelic/ }
        if type
          services = vcap_services[type]
          fail "Only one New Relic service can be bound.  Found '#{services.length}'" if services.length != 1

          license_key = services[0]['credentials']['licenseKey']
        end

        return license_key
      end

      def new_relic_home
        File.join @app_dir, NEW_RELIC_HOME
      end

  end

end
