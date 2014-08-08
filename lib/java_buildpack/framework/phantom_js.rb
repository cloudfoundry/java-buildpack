require 'java_buildpack/component/base_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/dash_case'
require 'shellwords'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for contributing custom Java options to an application.
    class PhantomJs < JavaBuildpack::Component::BaseComponent
      def detect
        'PhantomJs'
      end

      def compile
        archive_name = "phantomjs-#{version}-linux-x86_64.tar.bz2"
        package_uri = "#{repository_root}/#{archive_name}"

        download(version, package_uri) do |file|
          with_timing "Expanding PhantomJs to #{@droplet.sandbox.relative_path_from(@droplet.root)}" do
            FileUtils.mkdir_p @droplet.sandbox
            shell "tar xfvj #{file.path} -C #{@droplet.sandbox} --strip 1 2>&1"
          end
        end

        @droplet.copy_resources
        @droplet.java_opts.add_system_property('phantomjs.binary.path', phantom_path)
      end

      def release
        @droplet.java_opts.add_system_property('phantomjs.binary.path', phantom_path)
      end

      private

      def phantom_path
        "$PWD/#{(@droplet.sandbox + 'bin/phantomjs').relative_path_from(@droplet.root)}"
      end

      def version
        @configuration['version']
      end

      def repository_root
        @configuration['repository_root']
      end
    end
  end
end
