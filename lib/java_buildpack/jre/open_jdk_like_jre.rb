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

require 'ipaddr'
require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/jre'
require 'java_buildpack/util/tokenized_version'
require 'resolv'

module JavaBuildpack
  module Jre

    # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK-like JRE.
    class OpenJDKLikeJre < JavaBuildpack::Component::VersionedDependencyComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        @application    = context[:application]
        @component_name = context[:component_name]
        @configuration  = context[:configuration]
        @droplet        = context[:droplet]

        @droplet.java_home.root = @droplet.sandbox
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        @version, @uri             = JavaBuildpack::Repository::ConfiguredItem.find_item(@component_name,
                                                                                         @configuration)
        @droplet.java_home.version = @version
        super
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar
        @droplet.copy_resources
        disable_dns_caching if link_local_dns?

        return if @droplet.java_home.java_8_or_later?

        warn "\n       WARNING: You are using #{@droplet.java_home.version}. Oracle has ended public updates of Java " \
             "1.7 as of April 2015, possibly rendering your application vulnerable.\n\n"
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet
          .java_opts
          .add_system_property('java.io.tmpdir', '$TMPDIR')
      end

      private

      LINK_LOCAL = IPAddr.new('169.254.0.0/16').freeze

      private_constant :LINK_LOCAL

      def disable_dns_caching
        puts '       JVM DNS caching disabled in lieu of BOSH DNS caching'

        @droplet.networking.networkaddress_cache_ttl          = 0
        @droplet.networking.networkaddress_cache_negative_ttl = 0
      end

      def link_local_dns?
        Resolv::DNS::Config.new.lazy_initialize.nameserver_port.any? do |nameserver_port|
          LINK_LOCAL.include? IPAddr.new(nameserver_port[0])
        end
      end

    end

  end
end
