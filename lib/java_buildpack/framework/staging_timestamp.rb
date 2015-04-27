require 'java_buildpack/framework'

module JavaBuildpack::Framework

  # Adds a system property containing a timestamp of when the application was staged.
  class StagingTimestamp < JavaBuildpack::Component::BaseComponent
    def initialize(context)
      super(context)
    end

    def detect
      'staging-timestamp'
    end

    def compile
    end

    def release
      print "Hello ruby    "
      # @droplet.java_opts.add_system_property('staging.timestamp', "'#{Time.now}'")
    end
  end
end
