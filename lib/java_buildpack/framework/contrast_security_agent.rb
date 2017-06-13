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
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
require 'rexml/document'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for running the Contrast Security Agent support.
    class ContrastSecurityAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar(boot_class_name)
        build_contrast_configuration
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        app_name = @application.details['application_name'] || 'ROOT'
        java_opts = @droplet.java_opts
        java_opts.add_system_property('contrast.dir', '$TMPDIR')
        java_opts.add_system_property('contrast.override.appname', app_name)
        path = java_opts.qualify_path(@droplet.sandbox)
        java_opts.add_preformatted_options("-javaagent:#{path}/#{boot_class_name}=#{path}/contrast.config")
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service?(CONTRAST_FILTER, TEAMSERVER_URL, USERNAME, API_KEY, SERVICE_KEY)
      end

      private

      API_KEY = 'api_key'.freeze
      CONTRAST_FILTER = 'contrast-security'.freeze
      SERVICE_KEY = 'service_key'.freeze
      TEAMSERVER_URL = 'teamserver_url'.freeze
      USERNAME = 'username'.freeze

      private_constant :API_KEY
      private_constant :CONTRAST_FILTER
      private_constant :SERVICE_KEY
      private_constant :TEAMSERVER_URL
      private_constant :USERNAME

      PLUGIN_PACKAGE = 'com.aspectsecurity.contrast.runtime.agent.plugins.'.freeze

      def credentials
       @application.services.find_service(CONTRAST_FILTER)['credentials']
      end

      def boot_class_name
        version = @version.to_s.split('_')[0]
        "contrast-engine-#{version}.jar"
      end

      def build_contrast_configuration
        doc = REXML::Document.new
        contrast = doc.add_element('contrast')
        (contrast.add_element 'id').add_text('default')
        (contrast.add_element 'global-key').add_text(credentials[API_KEY])
        user = contrast.add_element('user')
        (user.add_element 'id').add_text(credentials[USERNAME])
        (user.add_element 'key').add_text(credentials[SERVICE_KEY])
        (contrast.add_element 'url').add_text("#{credentials[TEAMSERVER_URL]}/Contrast/s/")
        (contrast.add_element 'results-mode').add_text('never')

        add_plugins(contrast)

        contrast_config.open(File::CREAT | File::WRONLY) { |f| f.write(doc) }
      end

      def add_plugins(config)
        plugin_package = 'com.aspectsecurity.contrast.runtime.agent.plugins.'
        plugin_group = config.add_element('plugins')
        (plugin_group.add_element 'plugin').add_text("#{plugin_package}.security.SecurityPlugin")
        (plugin_group.add_element 'plugin').add_text("#{plugin_package}.architecture.ArchitecturePlugin")
        (plugin_group.add_element 'plugin').add_text("#{plugin_package}.appupdater.ApplicationUpdatePlugin")
        (plugin_group.add_element 'plugin').add_text("#{plugin_package}.sitemap.SitemapPlugin")
        (plugin_group.add_element 'plugin').add_text("#{plugin_package}.frameworks.FrameworkSupportPlugin")
        (plugin_group.add_element 'plugin').add_text("#{plugin_package}.http.HttpPlugin")
      end

      def contrast_config
        @droplet.sandbox + 'contrast.config'
      end

    end

  end
end