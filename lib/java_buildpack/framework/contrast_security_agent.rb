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
require 'java_buildpack/util/qualify_path'
require 'rexml/document'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for running the Contrast Security Agent support.
    class ContrastSecurityAgent < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
        @droplet.copy_resources

        write_configuration @application.services.find_service(FILTER, API_KEY, SERVICE_KEY, TEAMSERVER_URL,
                                                               USERNAME)['credentials']
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.java_opts
                .add_system_property('contrast.dir', '$TMPDIR')
                .add_system_property('contrast.override.appname', application_name)
                .add_preformatted_options("-javaagent:#{qualify_path(@droplet.sandbox + jar_name, @droplet.root)}=" \
                                          "#{qualify_path(contrast_config, @droplet.root)}")
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#jar_name)
      def jar_name
        @version < INFLECTION_VERSION ? "contrast-engine-#{short_version}.jar" : "java-agent-#{short_version}.jar"
      end

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, API_KEY, SERVICE_KEY, TEAMSERVER_URL, USERNAME
      end

      private

      API_KEY = 'api_key'.freeze

      FILTER = 'contrast-security'.freeze

      INFLECTION_VERSION = JavaBuildpack::Util::TokenizedVersion.new('3.4.3').freeze

      PLUGIN_PACKAGE = 'com.aspectsecurity.contrast.runtime.agent.plugins'.freeze

      SERVICE_KEY = 'service_key'.freeze

      TEAMSERVER_URL = 'teamserver_url'.freeze

      USERNAME = 'username'.freeze

      private_constant :API_KEY, :FILTER, :INFLECTION_VERSION, :PLUGIN_PACKAGE, :SERVICE_KEY, :TEAMSERVER_URL,
                       :USERNAME

      def add_contrast(doc, credentials)
        contrast = doc.add_element('contrast')
        (contrast.add_element 'id').add_text('default')
        (contrast.add_element 'global-key').add_text(credentials[API_KEY])
        (contrast.add_element 'url').add_text("#{credentials[TEAMSERVER_URL]}/Contrast/s/")
        (contrast.add_element 'results-mode').add_text('never')

        add_user contrast, credentials
        add_plugins contrast
      end

      def add_plugins(contrast)
        plugin_group = contrast.add_element('plugins')

        (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.security.SecurityPlugin")
        (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.architecture.ArchitecturePlugin")
        (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.appupdater.ApplicationUpdatePlugin")
        (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.sitemap.SitemapPlugin")
        (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.frameworks.FrameworkSupportPlugin")
        (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.http.HttpPlugin")
      end

      def add_user(contrast, credentials)
        user = contrast.add_element('user')
        (user.add_element 'id').add_text(credentials[USERNAME])
        (user.add_element 'key').add_text(credentials[SERVICE_KEY])
      end

      def application_name
        @application.details['application_name'] || 'ROOT'
      end

      def contrast_config
        @droplet.sandbox + 'contrast.config'
      end

      def short_version
        "#{@version[0]}.#{@version[1]}.#{@version[2]}"
      end

      def write_configuration(credentials)
        doc = REXML::Document.new

        add_contrast doc, credentials

        contrast_config.open(File::CREAT | File::WRONLY) { |f| f.write(doc) }
      end

    end

  end

end
