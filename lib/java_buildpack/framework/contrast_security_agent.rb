# Encoding: utf-8

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

require 'fileutils'
require 'open-uri'
require 'rexml/document'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
require 'base64'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for running the Contrast Security Agent support.
    class ContrastSecurityAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        load_credentials
        FileUtils.mkdir_p(@droplet.sandbox)
        @dir = @droplet.sandbox
        download_jar(boot_class_name)
        build_contrast_configuration
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        app_name = @application.details['application_name'] || 'ROOT'
        java_opts = @droplet.java_opts
        java_opts.add_system_property('contrast.dir', '/tmp')
        java_opts.add_system_property('contrast.override.appname', app_name)
        path = java_opts.qualify_path(@droplet.sandbox)
        java_opts.add_preformatted_options("-javaagent:#{path}/#{boot_class_name}=#{path}/contrast.config")
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service?(CONTRAST_FILTER, [TEAMSERVER_URL, USERNAME, API_KEY, SERVICE_KEY])
      end

      private

      CONTRAST_FILTER = /contrast[-]?security/
      private_constant :CONTRAST_FILTER

      TEAMSERVER_URL = 'teamserver_url'.freeze
      USERNAME = 'username'.freeze
      API_KEY = 'api_key'.freeze
      SERVICE_KEY = 'service_key'.freeze

      PLUGIN_PACKAGE = 'com.aspectsecurity.contrast.runtime.agent.plugins.'.freeze

      def load_credentials
        credentials = @application.services.find_service(CONTRAST_FILTER)['credentials']
        @teamserver_url = credentials[TEAMSERVER_URL]
        @username = credentials[USERNAME]
        @api_key = credentials[API_KEY]
        @service_key = credentials[SERVICE_KEY]
      end

      def boot_class_name
        version = @version.to_s.split('_')[0]
        "contrast-engine-#{version}.jar"
      end

      def build_contrast_configuration
        doc = REXML::Document.new
        contrast = doc.add_element('contrast')
        (contrast.add_element 'id').add_text('default')
        (contrast.add_element 'global-key').add_text(@api_key)
        user = contrast.add_element('user')
        (user.add_element 'id').add_text(@username)
        (user.add_element 'key').add_text(@service_key)
        (contrast.add_element 'url').add_text("#{@teamserver_url}/Contrast/s/")
        (contrast.add_element 'results-mode').add_text('never')

        add_plugins(contrast)

        File.open(File.join(@dir, 'contrast.config'), 'w+') do |file|
          file.puts doc
        end
      end

      def add_plugins(config)
        plugin_group = config.add_element('plugins')
        (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.security.SecurityPlugin")
        (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.architecture.ArchitecturePlugin")
        (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.appupdater.ApplicationUpdatePlugin")
        (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.sitemap.SitemapPlugin")
        (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.frameworks.FrameworkSupportPlugin")
        (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.http.HttpPlugin")
      end

    end

  end
end