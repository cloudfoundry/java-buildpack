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

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
module JavaBuildpack
  module Framework

    # Encapsulates the functionality for running the Riverbed AIX Agent support.
    class RiverbedAppinternalsAgent < JavaBuildpack::Component::VersionedDependencyComponent
      #jbp constants
      FILTER = /(?i)appinternals/

      #credentials key
      RVBD_DSA_PORT = 'rvbd_dsa_port'
      RVBD_AGENT_PORT = 'rvbd_agent_port'

      #javaagent args
      RVBD_MONIKER = 'rvbd_moniker'

      #env
      AIX_INSTRUMENT_ALL = 'AIX_INSTRUMENT_ALL'
      RVBD_AGENT_FILES = 'RVBD_AGENT_FILES'
      RVBD_DSA_HOST = 'RVBD_DSAHOST'
      DSA_PORT        = 'DSA_PORT'

      #constants
      DSA_PORT_DEFAULT        = 2111
      RVBD_AGENT_PORT_DEFAULT = 7073


      private_constant :FILTER, :RVBD_AGENT_PORT,
                       :DSA_PORT,
                       :RVBD_MONIKER,
                       :AIX_INSTRUMENT_ALL,
                       :RVBD_AGENT_FILES,
                       :RVBD_DSA_HOST,
                       :DSA_PORT_DEFAULT,
                       :RVBD_AGENT_PORT_DEFAULT,
                       :RVBD_DSA_PORT

      def initialize(context)
        super(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger RiverbedAppinternalsAgent
      end

      def compile
        download_zip(false, @droplet.sandbox, @component_name)
        @droplet.copy_resources

      end

      def release
        credentials = @application.services.find_service(FILTER)['credentials']
        setup_env credentials
        setup_javaopts credentials
      end

      def supports?
        @application.services.one_service?(FILTER) && os.casecmp('Linux') == 0
      end

      def setup_javaopts(credentials)
        @droplet.java_opts.add_agentpath(agent_path)
        rvbd_moniker = get_val_in_cred(RVBD_MONIKER, credentials[RVBD_MONIKER], nil, true)
        @droplet.java_opts.add_system_property('riverbed.moniker',rvbd_moniker) unless rvbd_moniker.nil?
      end

      def get_val_in_cred (property, credVal, default, logging)
        @logger.debug {"picks up credential #{property}:#{credVal}"} if credVal && logging
        #`echo "#{property},#{credVal},#{default},#{logging}\n" >> /#{@droplet.sandbox}/staging.log`
        credVal ? credVal : default
      end

      def setup_env (credentials)
        @droplet.environment_variables
          .add_environment_variable(DSA_PORT.upcase, get_val_in_cred(RVBD_DSA_PORT, credentials[RVBD_DSA_PORT], DSA_PORT_DEFAULT, true))
          .add_environment_variable(RVBD_AGENT_PORT.upcase, get_val_in_cred(RVBD_AGENT_PORT.upcase, credentials[RVBD_AGENT_PORT], RVBD_AGENT_PORT_DEFAULT, true))
          .add_environment_variable(AIX_INSTRUMENT_ALL,1)
          .add_environment_variable(RVBD_AGENT_FILES,1)
        dsa_host = @application.environment['CF_INSTANCE_IP']
        raise "expect CF_INSTANCE_IP to be set otherwise dsa_host is unavailable" unless dsa_host
        @droplet.environment_variables.add_environment_variable(RVBD_DSA_HOST, dsa_host)
      end

      def architecture
        `uname -m`.strip
      end

      def os
        `uname`.strip
      end

      def agent_path
        lib_dir + lib_ripl_name
      end

      def agent_dir
        @droplet.sandbox + 'agent'
      end

      def lib_dir
        agent_dir + 'lib'
      end

      def classes_dir
        agent_dir + 'classes'
      end

      def lib_ripl_name
        architecture == 'x86_64' || architecture == 'i686' ? 'librpilj64.so' : 'librpilj.so'
      end

    end
  end
end
