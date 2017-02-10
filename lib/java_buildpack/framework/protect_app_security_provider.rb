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
require 'shellwords'
require 'tempfile'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Safenet ProtectApp Java Security Provider support.
    class ProtectAppSecurityProvider < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_zip

		# copy default properties file
        @droplet.copy_resources

        credentials = @application.services.find_service(FILTER)['credentials']
		
        write_client credentials['client']
        write_trusted_certs credentials['trustedcerts']
				
        certificates.each_with_index { |certificate, index| add_certificate certificate, index }
        
		# setup java keystore with provided values
		merge_clientcert
		import_clientcert
		
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
		credentials = @application.services.find_service(FILTER)['credentials']
        java_opts   = @droplet.java_opts
		configuration = {}
		
		filter_known_input(credentials, configuration)
		
        write_java_opts(java_opts, configuration)
        @droplet.java_opts
          .add_system_property('java.ext.dirs', ext_dirs)
		  .add_system_property('com.ingrian.security.nae.IngrianNAE_Properties_Conf_Filename', @droplet.sandbox + 'IngrianNAE.properties')
		  .add_system_property('com.ingrian.security.nae.Key_Store_Location', key_store)
          .add_system_property('com.ingrian.security.nae.Key_Store_Password', password)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, 'client', 'trustedcerts'
      end

      private

      FILTER = /protectapp/.freeze

      private_constant :FILTER
	  
	  def merge_clientcert
		
        shell "openssl pkcs12 -export -in #{client_certificate} -inkey  #{client_private_key} -name  #{myclientcert} -out  #{myp12} -passout pass:#{password}" 
      end
	  
	  def import_clientcert
	  
        shell "#{keytool} -importkeystore -noprompt -destkeystore #{key_store} -deststorepass #{password} " \
			  "-srckeystore #{myp12} -srcstorepass #{password} -srcstoretype pkcs12" \
              " -alias #{myclientcert}"
      end

     def add_certificate(certificate, index)

        file = write_certificate certificate
        shell "#{keytool} -importcert -noprompt -keystore #{key_store} -storepass #{password} " \
              "-file #{file.to_path} -alias certificate-#{index}"
      end
	  
      def certificates
        certificates = []

        certificate = nil
        File.open(trusted_certificates).each_line do |line|
          if line =~ /BEGIN CERTIFICATE/
            certificate = line
          elsif line =~ /END CERTIFICATE/
            certificate += line
            certificates << certificate
            certificate = nil
          elsif !certificate.nil?
            certificate += line
          end
        end

        certificates
      end

      def keytool
        @droplet.java_home.root + 'bin/keytool'
      end

      def password
        'nae-jks-password'
      end

      def key_store
        @droplet.sandbox + 'keystore.jks'
      end

      def write_certificate(certificate)
        file = Tempfile.new('certificate-')
        file.write(certificate)
        file.fsync
        file
      end

      def ext_dir
        @droplet.sandbox + 'ext'
      end

      def ext_dirs
        "#{qualify_path(@droplet.java_home.root + 'lib/ext', @droplet.root)}:" \
        "#{qualify_path(ext_dir, @droplet.root)}"
      end
	  
	  def client_certificate
		File.join(Dir.tmpdir,'/client-certificate.pem')
      end

      def client_private_key
		File.join(Dir.tmpdir,'/client-private-key.pem')
      end

      def trusted_certificates
        File.join(Dir.tmpdir, 'trusted_certificates.pem')
      end
	  
	  def myclientcert
        'myclientcert'
      end
	  
	  def myp12
        File.join(Dir.tmpdir,'/clientwrap.p12')
      end

      def write_client(client)
        File.open(client_certificate, File::CREAT | File::WRONLY) do |f|
          f.write "#{client['certificate']}\n"
        end

        File.open(client_private_key, File::CREAT | File::WRONLY) do |f|
          f.write "#{client['private-key']}\n"
        end
      end
	  
      def write_trusted_certs(trusted_certs)
        File.open(trusted_certificates,File::CREAT | File::WRONLY) do |f|
          trusted_certs.each { |cert| f.write "#{cert}\n" }
        end
      end
	  
	  def filter_known_input(credentials, configuration)
		credentials.each do |key, value|
		  if key != "client" and key != "trustedcerts"
		    configuration[key] = value
		  end
        end
	  end
	  
	  def write_java_opts(java_opts, configuration2)
        configuration2.each do |key, value|
          	java_opts.add_system_property("com.ingrian.security.nae.#{key}", value )
        end
      end

    end
  end
end
