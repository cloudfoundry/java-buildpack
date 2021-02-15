
require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch JRebel support.
    class CodeInsightAgent < JavaBuildpack::Component::VersionedDependencyComponent

      def initialize(context, &version_validator)
        super(context, &version_validator)
        @component_name = 'CodeInsight-Java'
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_zip
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet
          .java_opts
          .add_javaagent(agent_jar)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        codeinsight_configured?(@droplet.sandbox + 'CodeInsight-Java.jar') &&
        codeinsight_configured?(@droplet.sandbox + 'CodeInsight-Java.xml')
      end

      private

      def codeinsight_configured?(root_path)
        (root_path).exist?
      end

      def agent_jar
        @droplet.sandbox + 'CodeInsight-Java.jar'
      end

    end

  end
end
