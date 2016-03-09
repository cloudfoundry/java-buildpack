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

require 'java_buildpack/logging'
require 'logger'

module JavaBuildpack
  module Logging

    # A +Logger+ subclass that forwards all messages to a collection of delegates
    class DelegatingLogger < ::Logger

      # Creates an instance
      #
      # @param [Class] klass the class to use as the +progname+ for log messages
      # @param [Array<Logger>] delegates the +Logger+ instances to delegate to
      def initialize(klass, delegates)
        @klass     = klass
        @delegates = delegates
      end

      # Adds a message to the delegate +Logger+ instances
      #
      # @param [Logger::Severity] severity the severity of the message
      # @param [String] message the message
      # @param [String] progname the message when passed in as a parameter
      # @yield evaluated for the message
      # @return [Void]
      def add(severity, message = nil, progname = nil, &block)
        @delegates.each { |delegate| delegate.add severity, message || progname, @klass, &block }
      end

    end

  end
end
