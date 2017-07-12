# Encoding: utf-8
# TODO License.

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
require 'fileutils'
require 'java_buildpack/util/qualify_path'
require 'java_buildpack/logging/logger_factory'

module JavaBuildpack
  module Framework

    # Installs JDT based LSP server component.
    class LanguageServerNodeCDX < JavaBuildpack::Component::VersionedDependencyComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger LanguageServerNodeCDX
      end


      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        @logger.debug { "Compile CDX" }
        # Install node js
        FileUtils.mkdir_p @droplet.root + "nodejs"
        nodedir = @droplet.sandbox + "nodejs"
        comp_version = @version
        comp_uri = @uri
        @version="8.0.0"
        @uri="https://buildpacks.cloudfoundry.org/dependencies/node/node-8.0.0-linux-x64-ade5a8e5.tgz"
        download_tar( target_directory=nodedir )
        @version = comp_version
        @uri = comp_uri
        download_zip strip_top_level = false
        @droplet.copy_resources

      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release

        @logger.debug { "Release CDX" }
        environment_variables = @droplet.environment_variables
        myWorkdir = @configuration["env"]["workdir"]
        environment_variables.add_environment_variable(ENV_PREFIX + "workdir", myWorkdir)
        myExec = @configuration["env"]["exec"]
        environment_variables.add_environment_variable(ENV_PREFIX + "exec", myExec)
        
        myIpc = @configuration["env"]["ipc"]
        @logger.debug { "CDX Env vars IPC:#{myIpc}" }
        myIpc.each do |key, value|
          environment_variables.add_environment_variable(ENV_PREFIX + key, value)
        end

        environment_variables.add_environment_variable 'PATH', "/home/vcap/app/.java-buildpack/#{@droplet.component_id}/nodejs/bin:$PATH"
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.environment.key?(LSPSERVERS) &&  @application.environment[LSPSERVERS].split(',').include?("cdx")
      end

      private

      LSPSERVERS = 'lspservers'.freeze

      private_constant :LSPSERVERS

      BINEXEC = 'exec'.freeze

      private_constant :BINEXEC

      ENV_PREFIX = 'LSPCDX_'.freeze

      private_constant :ENV_PREFIX

    end

  end
end
