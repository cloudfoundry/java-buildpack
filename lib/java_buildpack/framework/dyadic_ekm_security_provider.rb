# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Dyadic EKM Java Security Provider support.
    class DyadicEkmSecurityProvider < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar
        setup_ext_dir

       @droplet.copy_resources

       credentials = @application.services.find_service(FILTER)['credentials']
       write_key credentials['key']
       write_cert credentials['ca']
	   write_conf credentials['servers'], credentials['send_timeout'], credentials['recv_timeout'], credentials['retries']
	   end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
      @droplet
          .java_opts
          .add_system_property('java.library.path', @droplet.sandbox + 'usr/lib')
      @droplet.environment_variables.add_environment_variable 'LD_LIBRARY_PATH', @droplet.sandbox + 'usr/lib'

        @droplet
          .java_opts
          .add_system_property('java.security.properties', @droplet.sandbox + 'java.security')
          .add_system_property('java.ext.dirs', ext_dirs)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER
        #true
      end

      private

      FILTER = /dyadic/

      private_constant :FILTER

      def ext_dir
        @droplet.sandbox + 'ext'
      end
	  
	  def dyadic_jar
	   @droplet.sandbox + 'usr/lib/dsm/dsm-advapi-1.0.jar'
	  end

      def setup_ext_dir
        FileUtils.mkdir ext_dir     
        FileUtils.ln_s dyadic_jar.relative_path_from(ext_dir), ext_dir, force: true     
      end

      def ext_dirs
        "#{qualify_path(@droplet.java_home.root + 'lib/ext', @droplet.root)}:" \
        "#{qualify_path(ext_dir, @droplet.root)}"
      end
	  
	  def key_file
	    @droplet.sandbox + 'etc/dsm/key.pem'
      end
      
	  def cert_file
	    @droplet.sandbox + 'etc/dsm/ca.crt'
      end		  

	  def conf_file
	    @droplet.sandbox + 'etc/dsm/client.conf'
      end
	  	
	  def write_key(key)
        key_file.open(File::CREAT | File::WRONLY) do |f|
          f.write key
        end
      end
	  
	  def write_cert(cert)
        cert_file.open(File::CREAT | File::WRONLY) do |f|
          f.write cert
        end
      end
	  
	  def write_conf(servers,send_timeout,recv_timeout,retries)
        conf_file.open(File::CREAT | File::WRONLY) do |f|
          f.write "servers = " + servers + "\n"
		  f.write "send_timeout = " + send_timeout + "\n"
		  f.write "recv_timeout = " + recv_timeout + "\n"
		  f.write "retries = " + retries + "\n"
        end
      end  

    end
  end
end
